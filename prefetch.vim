" Copyright 2024 Oleksandr Kuvshynov

" -----------------------------------------------------------------------------
" configuration

" how many tokens to generate for each message
let g:qq_max_tokens = get(g:, 'qq_max_tokens', 1024)
" llama.cpp (or compatible) server
let g:qq_server = get(g:, 'qq_server', "http://localhost:8080/")
" default chat window width
let g:qq_width  = get(g:, 'qq_width'   , 80)
" format to use for datetime
let g:qq_timefmt = get(g:, 'qq_timefmt', "%Y-%m-%d %H:%M:%S ")

" -----------------------------------------------------------------------------
" script-level constants 

" should each session have its own file?
let s:sessions_file    = expand('~/.vim/qq_sessions.json')
" cleanup dead async jobs if list is longer than this
let s:n_jobs_cleanup   = 32
" auto-generated title max length
let s:qq_title_tokens  = 16
" delay between healthchecks
let s:healthcheck_ms   = 10000

" prepare endpoints for chat completion and healthcheck

" -----------------------------------------------------------------------------
" script-level mutable state

" Dead jobs are getting cleaned up after list goes over n_jobs_cleanup
let s:active_jobs = []
" this is the active session id. New queries would go to this session by default
let s:current_session = -1 
" latest healthcheck result. global so that statusline can access it
let g:qq_server_status = "unknown"

" {{{ Chats - DB-like layer for chats/messages 

let s:Chats = {}

function! s:Chats.init() dict
    if filereadable(s:sessions_file)
        let self._chats = json_decode(join(readfile(s:sessions_file), ''))
    endif
endfunction

function! s:Chats._save() dict
    let l:sessions_text = json_encode(self._chats)
    silent! call writefile([l:sessions_text], s:sessions_file)
endfunction

function! s:Chats.append_partial(session_id, part) dict
    call add(self._chats[a:session_id].partial_reply, a:part)
    call s:Chats._save()
endfunction

function! s:Chats.has_title(session_id) dict
    return self._chats[a:session_id].title_computed
endfunction

function! s:Chats.set_title(session_id, title) dict
    let self._chats[a:session_id].title          = a:title
    let self._chats[a:session_id].title_computed = v:true
    call s:Chats._save()
endfunction

function! s:Chats.get_first_message(session_id) dict
    return self._chats[a:session_id].messages[0].content
endfunction

function! s:Chats.append_message(session_id, message) dict
    let l:message = copy(a:message)
    if !has_key(l:message, 'timestamp')
        let l:message['timestamp'] = localtime()
    endif

    call add(self._chats[a:session_id].messages, l:message)
    call s:Chats._save()

    return l:message
endfunction

function! s:Chats._last_updated(session) dict
    let l:time = a:session.timestamp
    for l:message in reverse(copy(a:session.messages))
        if has_key(l:message, 'timestamp')
            let l:time = l:message.timestamp
            break
        endif
    endfor
    return l:time
endfunction

function! s:Chats.get_ordered_chats() dict
    let l:session_list = []
    for [key, session] in items(self._chats)
        let l:session_list += [{'title': session.title, 'id': session.id, 'time': s:Chats._last_updated(session)}]
    endfor
    return sort(l:session_list, {a, b -> a.time > b.time ? - 1 : a.time < b.time ? 1 : 0})
endfunction

" TODO - should we return a copy and not a reference?
function! s:Chats.get_messages(session_id) dict
    return self._chats[a:session_id].messages
endfunction

function! s:Chats.get_partial(session_id) dict
    return join(self._chats[a:session_id].partial_reply, '')
endfunction

function! s:Chats.clear_partial(session_id) dict
    let self._chats[a:session_id].partial_reply = []
endfunction

function! s:Chats.partial_done(session_id) dict
    let l:reply = join(self._chats[a:session_id].partial_reply, '')
    call s:Chats.append_message(a:session_id, {"role": "assistant", "content": l:reply})
    let self._chats[a:session_id].partial_reply = []
endfunction

function! s:Chats.new_chat()
    let l:session = {}
    let l:session.id = empty(self._chats) ? 1 : max(keys(self._chats)) + 1
    let l:session.messages = []
    let l:session.partial_reply = []
    let l:session.title = "new chat"
    let l:session.title_computed = v:false
    let l:session.timestamp = localtime()

    let self._chats[l:session.id] = l:session

    call s:Chats._save()

    return l:session.id
endfunction

call s:Chats.init()

" }}}

" get or create a new session if there isn't one
function! s:current_session_id()
    if s:current_session == -1
        let s:current_session = s:Chats.new_chat()
    endif
    return s:current_session
endfunction


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

" {{{  llama server client
let s:Server = {}

function s:Server._on_status_exit(exit_status) dict
    if a:exit_status != 0
        " this should modify local variable, and call some fn
        let g:qq_server_status = "unavailable"
    endif
    " call some callback
    call s:redraw_status()
    " restart again. 
    call timer_start(s:healthcheck_ms, { -> s:Server._get_status() })
endfunction

function s:Server._on_status_out(msg) dict
    let l:status = json_decode(a:msg)
    if empty(l:status)
        let g:qq_server_status = "unavailable"
    else
        let g:qq_server_status = l:status.status
    endif
endfunction

function s:Server._get_status() dict
    let l:curl_cmd = ["curl", "--max-time", "5", self._status_endpoint]
    let l:job_conf = {
          \ 'out_cb' : {channel, msg   -> self._on_status_out(msg)},
          \ 'exit_cb': {job_id, status -> self._on_status_exit(status)}
    \}

    call s:keep_job(job_start(l:curl_cmd, l:job_conf))
endfunction

function! s:Server.init() dict
    let l:server = substitute(g:qq_server, '/*$', '', '')
    let self._chat_endpoint   = l:server . '/v1/chat/completions'
    let self._status_endpoint = l:server . '/health'
    call s:Server._get_status()
endfunction

function s:Server._send_chat_query(req, job_conf) dict
    let l:json_req  = json_encode(a:req)
    let l:json_req  = substitute(l:json_req, "'", "'\\\\''", "g")

    let l:curl_cmd  = "curl --no-buffer -s -X POST '" . self._chat_endpoint . "'"
    let l:curl_cmd .= " -H 'Content-Type: application/json'"
    let l:curl_cmd .= " -d '" . l:json_req . "'"

    call s:keep_job(job_start(['/bin/sh', '-c', l:curl_cmd], a:job_conf))
endfunction

function! s:Server._on_stream_out(session_id, msg) dict
    if a:msg !~# '^data: '
        return
    endif
    let json_string = substitute(a:msg, '^data: ', '', '')

    let response = json_decode(json_string)
    if has_key(response.choices[0].delta, 'content')
        let next_token = response.choices[0].delta.content
        call s:Chats.append_partial(a:session_id, next_token)
        " TODO: rather than doing this, our UI subscribes to updates from DB?
        call s:maybe_append_token(a:session_id, next_token)
    endif
endfunction

function! s:Server._on_stream_close(session_id)
    call s:Chats.partial_done(a:session_id)

    " TODO - need to subscribe to something here as well
    if !s:Chats.has_title(a:session_id)
        call self.send_gen_title(a:session_id, s:Chats.get_first_message(a:session_id))
    endif
endfunction

function! s:Server._on_err(session_id, msg)
    " TODO: logging
endfunction

function! s:Server._on_title_out(session_id, msg)
    let json_string = substitute(a:msg, '^data: ', '', '')

    let response = json_decode(json_string)
    if has_key(response.choices[0].message, 'content')
        let title = response.choices[0].message.content
        call s:Chats.set_title(a:session_id, title)
    endif
endfunction

" warmup query to pre-fill the cache on the server.
" We ask for 0 tokens and ignore the response.
function! s:Server.send_warmup(session_id, question) dict
    let req = {}
    let req.messages     = s:Chats.get_messages(a:session_id) + [{"role": "user", "content": a:question}]
    let req.n_predict    = 0
    let req.stream       = v:true
    let req.cache_prompt = v:true

    call self._send_chat_query(req, {})
endfunction

" assumes the last message is already in the session 
function! s:Server.send_chat(session_id) dict
    let req = {}
    let req.messages     = s:Chats.get_messages(a:session_id)
    let req.n_predict    = g:qq_max_tokens
    let req.stream       = v:true
    let req.cache_prompt = v:true

    call s:Chats.clear_partial(a:session_id)

    let l:job_conf = {
          \ 'out_cb'  : {channel, msg -> self._on_stream_out(a:session_id, msg)}, 
          \ 'err_cb'  : {channel, msg -> self._on_err(a:session_id, msg)},
          \ 'close_cb': {channel      -> self._on_stream_close(a:session_id)}
    \ }

    call self._send_chat_query(req, l:job_conf)
endfunction

" ask for a title we'll use in UI. Uses first message in a chat session
" TODO: this actually pollutes the kv cache for next messages.
function! s:Server.send_gen_title(session_id, message_text)
    let req = {}
    let prompt = "Write a title with a few words summarizing the following paragraph. Reply only with title itself. Use no quotes around it.\n\n"
    let req.messages  = [{"role": "user", "content": prompt . a:message_text}]
    let req.n_predict    = s:qq_title_tokens
    let req.stream       = v:false
    let req.cache_prompt = v:true

    let l:job_conf = {
          \ 'out_cb': {channel, msg -> s:Server._on_title_out(a:session_id, msg)}
    \ }

    call s:Server._send_chat_query(req, l:job_conf)
endfunction

call s:Server.init()

" }}}

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
    let l:message    = s:Chats.append_message(l:session_id, l:message)

    call s:print_message(v:true, l:message)
    call s:display_prompt()
    call s:Server.send_chat(l:session_id)
endfunction

function! s:qq_warmup()
    let l:context = s:get_visual_selection()
    if !empty(l:context)
        call timer_start(0, { -> s:preprocess(l:context) })
    endif
    call feedkeys(":'<,'>QQ ", 'n')
endfunction

function! s:preprocess(context)
    let l:prompt = s:fmt_question(a:context, "")
    let l:session_id = s:current_session_id() 
    call s:Server.send_warmup(l:session_id, l:prompt)
endfunction

" -----------------------------------------------------------------------------
" utilities for buffer/chat window manipulation

function! s:redraw_status()
    " TODO: redraw too much? What if one of the buffers has expensive function
    " in its statusline?
    redrawstatus!
endfunction

function! s:open_chat_window()
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
function! s:toggle_chat_window()
    let bufnum = bufnr('vim_qna_chat')
    if bufnum == -1
        call s:open_chat_window()
    else
        let l:winid = bufwinid('vim_qna_chat')
        if l:winid != -1
            call win_gotoid(l:winid)
            silent! execute 'hide'
        else
            call s:open_chat_window()
        endif
    endif
endfunction

function! s:wrap_prompt(prompt)
    return a:prompt
endfunction

" appends a single message to the buffer
function! s:print_message(open_chat, message)
    if a:open_chat
        call s:open_chat_window()
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
    let prompt = s:wrap_prompt(prompt)
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

function! s:display_prompt()
    " do that only if chat is open?
    let l:bufnum  = bufnr('vim_qna_chat')
    let l:msg     = s:wrap_prompt(strftime(g:qq_timefmt . " Local: "))
    let l:lines   = split(l:msg, '\n')
    call appendbufline(l:bufnum, line('$'), l:lines)
endfunction

function! s:display_session(session_id)
    call s:open_chat_window()
    let s:current_session = a:session_id

    mapclear <buffer>
    setlocal modifiable
    silent! call deletebufline('%', 1, '$')

    for l:message in s:Chats.get_messages(a:session_id)
        call s:print_message(v:false, l:message)
    endfor

    " display streamed partial response
    let l:partial = s:Chats.get_partial(a:session_id)
    if !empty(l:partial)
        let l:msg = s:wrap_prompt(strftime(g:qq_timefmt . " Local: ")) . l:partial
        let l:lines = split(l:msg, '\n')
        call append(line('$'), l:lines)
    endif

    nnoremap <silent> <buffer> q  :call <SID>show_chat_list()<CR>
endfunction

function! s:new_chat()
    let s:current_session = s:Chats.new_chat()
    call s:display_session(s:current_session)
endfunction

" -----------------------------------------------------------------------------
" session selection TUI
function! s:select_chat()
    let l:session_id = s:session_id_map[line('.')]
    call s:display_session(l:session_id)
endfunction

function! s:show_chat_list()
    let l:titles = []
    let s:session_id_map = {}

    for item in s:Chats.get_ordered_chats()
        call add(l:titles, strftime(g:qq_timefmt . " " . item.title, item.time))
        let s:session_id_map[len(titles)] = item.id
        if s:current_session == item.id
            let l:selected_line = len(titles)
        endif
    endfor

    call s:open_chat_window()

    setlocal modifiable
    silent! call deletebufline('%', 1, '$')
    call setline(1, l:titles)
    if exists('l:selected_line')
        call cursor(l:selected_line, 1)
    endif
    " TODO - turn it off when viewing the individual chat
    setlocal cursorline
    setlocal nomodifiable
    
    mapclear <buffer>
    nnoremap <silent> <buffer> <CR> :call <SID>select_chat()<CR>
    nnoremap <silent> <buffer> q    :call <SID>toggle_chat_window()<CR>
endfunction

" -----------------------------------------------------------------------------
"  commands and default key mappings
xnoremap <silent> QQ         :<C-u>call <SID>qq_warmup()<CR>
nnoremap <silent> <leader>qq :call      <SID>toggle_chat_window()<CR>
nnoremap <silent> <leader>qp :call      <SID>show_chat_list()<CR>

command! -range -nargs=+ QQ  call s:qq_send_message(<q-args>, v:true)
command!        -nargs=+ Q   call s:qq_send_message(<q-args>, v:false)
command!        -nargs=1 QL  call s:display_session(<f-args>)
command!        -nargs=0 QN  call s:new_chat()
command!        -nargs=0 QP  call s:show_chat_list()
