" Copyright 2024 Oleksandr Kuvshynov

" -----------------------------------------------------------------------------
" configuration
" how many tokens to generate for each message
let g:qq_max_tokens = get(g:, 'qq_max_tokens', 1024)

let g:qq_server = get(g:, 'qq_server', "http://localhost:8080/")
" default window width
let g:qq_width  = get(g:, 'qq_width'   , 80)

let g:qq_timefmt = get(g:, 'qq_timefmt', "%Y-%m-%d %H:%M:%S ")

" -----------------------------------------------------------------------------
" script-level constants 

" should each session have its own file?
let s:sessions_file    = expand('~/.vim/qq_sessions.json')
" cleanup dead jobs if list is longer than this
let s:n_jobs_cleanup   = 32
" auto-generated title length
let s:qq_title_tokens  = 16
" pause between healthchecks
let s:healthcheck_ms   = 10000

" prepare endpoints
let s:qq_server          = substitute(g:qq_server, '/*$', '', '')
let s:qq_chat_endpoint   = s:qq_server . '/v1/chat/completions'
let s:qq_health_endpoint = s:qq_server . '/health'

" -----------------------------------------------------------------------------
" script-level mutable state

" Dead jobs are getting cleaned up after list goes over n_jobs_cleanup
" TODO: make this a dictionary
let s:active_jobs = []

"  sessions need to be a dictionary, not a list and ids need to be assigned
"  differently. This way we can delete it.
let s:sessions = []
let s:current_session = -1 " this is the active session, all qq would go to it
let g:qq_server_status = "unknown"

" -----------------------------------------------------------------------------
" rename these to chats?

function! s:load_sessions()
    let s:sessions = []
    if filereadable(s:sessions_file)
        let s:sessions = json_decode(join(readfile(s:sessions_file), ''))
    endif
endfunction

function! s:save_sessions()
    let l:sessions_text = json_encode(s:sessions)
    silent! call writefile([l:sessions_text], s:sessions_file)
endfunction

function! s:start_session()
    let l:session = {}
    let l:session.id = len(s:sessions)
    let l:session.messages = []
    let l:session.partial_reply = []
    let l:session.title = "new chat"
    let l:session.title_computed = v:false
    let l:session.timestamp = localtime()

    let s:sessions += [l:session]

    let s:current_session = l:session.id
    call s:save_sessions()
endfunction

" get or create a new session if there isn't one
function! s:current_session_id()
    if s:current_session == -1
        call s:start_session()
    endif
    return s:current_session
endfunction

function! s:current_messages()
    let l:sid = s:current_session_id()
    return s:sessions[l:sid].messages
endfunction

function! s:append_message(session_id, msg_j)
    let l:msg = copy(a:msg_j)
    if !has_key(l:msg, 'timestamp')
        let l:msg['timestamp'] = localtime()
    endif

    call add(s:sessions[a:session_id].messages, l:msg)
    call s:save_sessions()

    return l:msg
endfunction

" load sessions once
call s:load_sessions()

" -----------------------------------------------------------------------------
" async jobs management
function! s:keep_job(job_id)
    let s:active_jobs += [a:job_id]
    if len(s:active_jobs) > s:n_jobs_cleanup
        for job_id in s:active_jobs[:]
            if job_info(job_id)['status'] == 'dead'
                call remove(s:active_jobs, index(s:active_jobs, job_id))
            endif
        endfor
    endif
endfunction

" -----------------------------------------------------------------------------
"  server healthchecks

function s:on_status_exit(job, exit_status)
    if a:exit_status != 0
        let g:qq_server_status = "unavailable"
    endif
    call s:redraw_status()
    " restart again. 
    call timer_start(s:healthcheck_ms, { -> s:get_server_status() })
endfunction

function s:on_status(channel, msg)
    let l:status = json_decode(a:msg)
    if empty(l:status)
        let g:qq_server_status = "unavailable"
    else
        let g:qq_server_status = l:status.status
    endif
endfunction

function s:get_server_status()
    let l:curl_cmd = ["curl", "--max-time", "5", s:qq_health_endpoint]
    let l:job_conf = {'out_cb': 's:on_status', 'exit_cb': 's:on_status_exit'}

    call s:keep_job(job_start(l:curl_cmd, l:job_conf))
endfunction

call s:get_server_status()

" -----------------------------------------------------------------------------
"  llama server callbacks with token streaming

function! s:on_out(session_id, msg)
    if a:msg !~# '^data: '
        return
    endif
    let json_string = substitute(a:msg, '^data: ', '', '')

    let response = json_decode(json_string)
    if has_key(response.choices[0].delta, 'content')
        let next_token = response.choices[0].delta.content
        call add(s:sessions[a:session_id].partial_reply, next_token)
        call s:maybe_append_token(a:session_id, next_token)
        call s:save_sessions()
    endif
    " TODO: not move the cursor here so I can copy/paste? Make it optional.
    "silent! call win_execute(bufwinid('vim_qna_chat'), 'normal! G')
endfunction

function! s:on_close(session_id)
    let l:reply = join(s:sessions[a:session_id].partial_reply, '')
    call s:append_message(a:session_id, {"role": "assistant", "content": l:reply})
    let s:sessions[a:session_id].partial_reply = []

    if !s:sessions[a:session_id].title_computed
        call s:prepare_title(a:session_id, s:sessions[a:session_id].messages[0].content)
    endif
endfunction

function! s:on_err(session_id, msg)
    " TODO: logging
endfunction

function! s:on_title_out(session_id, msg)
    let json_string = substitute(a:msg, '^data: ', '', '')

    let response = json_decode(json_string)
    if has_key(response.choices[0].message, 'content')
        let title = response.choices[0].message.content
        let s:sessions[a:session_id].title = title
        let s:sessions[a:session_id].title_computed = v:true
        call s:save_sessions()
    endif
endfunction

" -----------------------------------------------------------------------------
"  llama server 

function s:send_query(req, job_conf)
    let l:json_req = json_encode(a:req)
    let l:json_req = substitute(l:json_req, "'", "'\\\\''", "g")

    let l:curl_cmd  = "curl --no-buffer -s -X POST '" . s:qq_chat_endpoint . "'"
    let l:curl_cmd .= " -H 'Content-Type: application/json'"
    let l:curl_cmd .= " -d '" . l:json_req . "'"

    call s:keep_job(job_start(['/bin/sh', '-c', l:curl_cmd], a:job_conf))
endfunction

" Priming query to pre-fill the cache on the server.
" We ask for 0 tokens and ignore the response.
function! s:prime_local(question)
    let req          = {}
    let req.messages = s:current_messages() + [{"role": "user", "content": a:question}]
    let req.n_predict    = 0
    let req.stream       = v:true
    let req.cache_prompt = v:true

    call s:send_query(req, {})
endfunction

" assumes the last message is already in the session 
function! s:ask_local()
    let l:sid = s:current_session_id()

    let req = {}
    let req.messages     = s:current_messages()
    let req.n_predict    = g:qq_max_tokens
    let req.stream       = v:true
    let req.cache_prompt = v:true

    let s:sessions[l:sid].partial_reply = []

    let l:job_conf = {
          \ 'out_cb'  : {channel, msg -> s:on_out(l:sid, msg)}, 
          \ 'err_cb'  : {channel, msg -> s:on_err(l:sid, msg)},
          \ 'close_cb': {channel      -> s:on_close(l:sid)}
    \ }

    " just display the prompt maybe?
    call s:display_partial_response(l:sid)
    call s:send_query(req, l:job_conf)

endfunction

" create a title we'll use in UI. message text is just a text.
function! s:prepare_title(session_id, message_text)
    let req = {}
    let req.messages  = [{"role": "user", "content": "Write a title with a few words summarizing the following paragraph. Reply only with title itself.\n\n" . a:message_text}]
    let req.n_predict    = s:qq_title_tokens
    let req.stream       = v:false
    let req.cache_prompt = v:true

    let l:job_conf = {'out_cb': {channel, msg -> s:on_title_out(a:session_id, msg)}}

    call s:send_query(req, l:job_conf)
endfunction

" -----------------------------------------------------------------------------
"  utility function to get visual selection
function! s:get_visual_selection()
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end  , column_end  ] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0]  = lines[0][column_start - 1:]
    return join(lines, "\n")
endfunction

function! s:fmt_question(context, question)
    return "Here's a code snippet: \n\n " . a:context . "\n\n" . a:question
endfunction

function! s:qq_send_message(question, use_context)
    let l:context = s:get_visual_selection()
    if a:use_context
        let l:question = s:fmt_question(l:context, a:question)
    else
        let l:question = a:question
    endif
    let l:message  = {"role": "user", "content": l:question}
    let l:session_id = s:current_session_id() 
    " timestamp and other metadata might get appended here
    let l:message    = s:append_message(l:session_id, l:message)

    call s:print_message(v:true, l:message)
    call s:ask_local()
endfunction

function! s:qq_prepare(in_new_chat)
    let l:context = s:get_visual_selection()
    if a:in_new_chat
        call s:start_session()
        call s:display_session(s:current_session)
    endif
    if !empty(l:context)
        call timer_start(0, { -> s:preprocess(l:context) })
    endif
    call feedkeys(":'<,'>QQ ", 'n')
endfunction

function! s:preprocess(context)
    let l:prompt = s:fmt_question(a:context, "")
    call s:prime_local(l:prompt)
endfunction

" -----------------------------------------------------------------------------
" utilities for buffer/chat window manipulation

function! s:redraw_status()
    " TODO: redraw too much? What if one of the buffers has expensive function
    " in its statusline?
    redrawstatus!
endfunction

function! s:open_chat()
    " Check if the buffer already exists
    let l:bufnum = bufnr('vim_qna_chat')
    if l:bufnum == -1
        " Create a new buffer in a vertical split
        silent! execute 'topleft vertical ' . g:qq_width . ' new'
        silent! execute 'edit vim_qna_chat'
        setlocal buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
        setlocal statusline=server\ status:\ %{qq_server_status}
    else
        let winnum = bufwinnr(l:bufnum)
        if winnum == -1
            silent! execute 'topleft vertical ' . g:qq_width . ' split'
            silent! execute 'buffer ' l:bufnum
        else
            silent! execute winnum . 'wincmd w'
        endif
    endif
    return l:bufnum
endfunction

" -----------------------------------------------------------------------------
" clear buffer-local mappings
function! s:clear_mappings()
    mapclear <buffer>
endfunction

function! s:toggle_chat_window()
    let bufnum = bufnr('vim_qna_chat')
    if bufnum == -1
        call s:open_chat()
    else
        let l:winid = bufwinid('vim_qna_chat')
        if l:winid != -1
            call win_gotoid(l:winid)
            silent! execute 'hide'
        else
            call s:open_chat()
        endif
    endif
endfunction

" appends a single message to the buffer
function! s:print_message(open_chat, message)
    if a:open_chat
        call s:open_chat()
    endif

    let l:tstamp = "        "
    if has_key(a:message, 'timestamp')
        let l:tstamp = strftime(g:qq_timefmt . " ", a:message['timestamp'])
    endif
    if a:message['role'] == 'user'
        let prompt = l:tstamp . "  You: "
    else
        let prompt = l:tstamp . "Local: "
    endif
    let lines = split(a:message['content'], '\n')
    for l in lines
        if line('$') == 1 && getline(1) == ''
            call setline(1, prompt . l)
        else
            call append(line('$'), prompt . l)
        endif
        let prompt = ''
    endfor

    normal! G
endfunction

function! s:maybe_append_token(session_id, token)
    if s:current_session == a:session_id
        let l:bufnum    = bufnr('vim_qna_chat')
        let l:curr_line = getbufoneline(bufnum, '$')
        silent! call setbufline(l:bufnum, '$', split(l:curr_line . a:token . "\n", '\n'))
    endif
endfunction

function! s:display_partial_response(session_id)
    let l:partial = join(s:sessions[a:session_id].partial_reply, '')
    let l:bufnum = bufnr('vim_qna_chat')
    let l:msg = strftime(g:qq_timefmt . " Local: ") . l:partial
    let l:lines = split(l:msg, '\n')
    call appendbufline(l:bufnum, line('$'), l:lines)
endfunction

function! s:display_session(session_id)
    call s:load_sessions()
    call s:open_chat()
    let s:current_session = a:session_id

    call s:clear_mappings()
    setlocal modifiable
    silent! call deletebufline('%', 1, '$')

    for l:msg in s:sessions[a:session_id].messages
        call s:print_message(v:false, l:msg)
    endfor

    " display in progress streamed response
    let l:partial = join(s:sessions[a:session_id].partial_reply, '')
    if !empty(l:partial)
        let l:msg = strftime(g:qq_timefmt . " Local: ") . l:partial
        let l:lines = split(l:msg, '\n')
        call append(line('$'), l:lines)
    endif
endfunction

function! s:new_chat()
    call s:start_session()
    call s:display_session(s:current_session)
endfunction

" -----------------------------------------------------------------------------
" session selection TUI
function! s:select_title()
    let l:session_id = s:session_id_map[line('.')]
    call s:display_session(l:session_id)
endfunction

function! s:pick_session()
    let l:titles = []
    let s:session_id_map = {}
    for i in range(len(s:sessions))
        if has_key(s:sessions[i], 'title')
            let l:title = s:sessions[i].title
            if has_key(s:sessions[i], 'timestamp')
                let l:time  = s:sessions[i].timestamp
            endif
            for l:msg in reverse(s:sessions[i].messages)
                if has_key(l:msg, 'timestamp')
                    let l:time = l:msg.timestamp
                    break
                endif
            endfor
            if exists('l:time')
                call add(titles, strftime(g:qq_timefmt . " " . l:title, l:time))
            else
                let default_time = repeat('-', strlen(strftime(g:qq_timefmt, 0)))
                call add(titles, default_time . " " . l:title)
            endif
            let s:session_id_map[len(titles)] = i
            if s:current_session == i
                let l:selected_line = len(titles)
            endif 
        endif
    endfor

    call s:open_chat()

    setlocal modifiable
    silent! call deletebufline('%', 1, '$')
    call setline(1, l:titles)
    if exists('l:selected_line')
        call cursor(l:selected_line, 1)
    endif
    " TODO - turn it off when viewing the individual chat
    setlocal cursorline
    setlocal nomodifiable
    
    call s:clear_mappings()
    nnoremap <silent> <buffer> <CR> :call <SID>select_title()<CR>
    nnoremap <silent> <buffer> q    :call <SID>toggle_chat_window()<CR>
endfunction

" -----------------------------------------------------------------------------
"  commands and default key mappings
xnoremap <silent> QQ         :<C-u>call <SID>qq_prepare(v:false)<CR>
" TODO: this seems broken
xnoremap <silent> QN         :<C-u>call <SID>qq_prepare(v:true)<CR>
nnoremap <silent> <leader>qq :call      <SID>toggle_chat_window()<CR>
nnoremap <silent> <leader>qp :call      <SID>pick_session()<CR>

command! -range -nargs=+ QQ  call s:qq_send_message(<q-args>, v:true)
command!        -nargs=+ Q   call s:qq_send_message(<q-args>, v:false)
command!        -nargs=1 QL  call s:display_session(<f-args>)
command!        -nargs=0 QN  call s:new_chat()
command!        -nargs=0 QP  call s:pick_session()
command!        -nargs=0 QS  call s:get_server_status()
