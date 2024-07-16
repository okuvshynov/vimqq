" Copyright 2024 Oleksandr Kuvshynov

" -----------------------------------------------------------------------------
" configuration
" how many tokens to generate for each message
let g:qq_max_tokens = get(g:, 'qq_max_tokens', 1024)

let g:qq_server = get(g:, 'qq_server', "http://localhost:8080/")
" default window width
let g:qq_width    = get(g:, 'qq_width'   , 80)

" -----------------------------------------------------------------------------
" should each session have its own file?
let s:sessions_file    = expand('~/.vim/qq_sessions.json')
" cleanup dead jobs if list is longer than this
let s:n_jobs_cleanup   = 32

" prepare endpoints
let s:qq_server          = substitute(g:qq_server, '/*$', '', '')
let s:qq_chat_endpoint   = s:qq_server . '/v1/chat/completions'
let s:qq_health_endpoint = s:qq_server . '/health'

" -----------------------------------------------------------------------------
" script-level mutable state

" Dead tasks are getting cleaned up after list goes over n_jobs_cleanup
let s:active_jobs = []

"  Do we have one window for chat? Or can open as many as we wish?
let s:sessions = []
let s:current_session = -1 " this is the active session, all qq would go to it

" -----------------------------------------------------------------------------
" history and sessions

function! s:load_sessions()
    let s:sessions = []
    if filereadable(s:sessions_file)
        let s:sessions = json_decode(join(readfile(s:sessions_file), ''))
    endif
endfunction

" load sessions once
call s:load_sessions()

function! s:save_sessions()
    let l:sessions_text = json_encode(s:sessions)
    silent! call writefile([l:sessions_text], s:sessions_file)
endfunction

function! s:start_session()
    let l:session = {}
    let l:session.id = len(s:sessions)
    let l:session.messages = []
    let l:session.current_reply = ""

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

" appends message to current session and saves to file
function! s:append_message(msg_j)
    let l:msg = copy(a:msg_j)
    if !has_key(l:msg, 'timestamp')
        let l:msg['timestamp'] = localtime()
    endif

    let l:sid = s:current_session_id()

    call add(s:sessions[l:sid].messages, l:msg)
    call s:save_sessions()

    return l:msg
endfunction

" -----------------------------------------------------------------------------
" async jobs management
function! s:save_job(job_id)
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
"  server interactions

function s:send_query(req, job_conf)
    let l:json_req = json_encode(a:req)
    let l:json_req = substitute(l:json_req, "'", "'\\\\''", "g")

    let l:curl_cmd  = "curl --no-buffer -s -X POST '" . s:qq_chat_endpoint . "'"
    let l:curl_cmd .= " -H 'Content-Type: application/json'"
    let l:curl_cmd .= " -d '" . l:json_req . "'"

    call s:save_job(job_start(['/bin/sh', '-c', l:curl_cmd], a:job_conf))
endfunction

" sync operation. currently unused.
function s:server_status_impl()
    let l:curl_cmd = "curl --max-time 5 -s '" . s:qq_health_endpoint . "'"
    let l:output   = system(l:curl_cmd)
    let l:status   = json_decode(l:output)
    if empty(l:status)
        let s:server_status = "unavailable"
    else
        let s:server_status = l:status.status
    endif
endfunction

" -----------------------------------------------------------------------------
"  llama_duo callbacks - with streaming

function! s:on_out(channel, msg)
    if a:msg !~# '^data: '
        return
    endif
    let json_string = substitute(a:msg, '^data: ', '', '')

    let bufnum = bufnr('vim_qna_chat')
    let response = json_decode(json_string)
    let l:sid = s:current_session_id()
    if has_key(response.choices[0].delta, 'content')
        let next_token = response.choices[0].delta.content
        let curr_line = getbufoneline(bufnum, '$')
        silent! call setbufline(bufnum, '$', split(curr_line . next_token . "\n", '\n'))
        let s:sessions[l:sid].current_reply = s:sessions[l:sid].current_reply . next_token
    endif
    " TODO: not move the cursor here so I can copy/paste? Make it optional.
    "silent! call win_execute(bufwinid('vim_qna_chat'), 'normal! G')
endfunction

function! s:on_close(channel)
    " appends to active session, creates new session if there's no sessions
    let l:sid = s:current_session_id()
    call s:append_message({"role": "assistant", "content": s:sessions[l:sid].current_reply})
    let s:sessions[l:sid].current_reply = ""
endfunction

function! s:on_err(channel, msg)
    " TODO: logging
endfunction


" -----------------------------------------------------------------------------
"  llama server requests preparation

" query to pre-fill the cache
function! s:prime_local(question)
    let l:sid = s:current_session_id()
    let req = {}
    let req.messages  = s:current_messages() + [{"role": "user", "content": a:question}]
    let req.n_predict = 0
    let req.stream = v:true
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

    let s:sessions[l:sid].current_reply = ""

    " TODO: we need to pass session id to callbacks to make sure we append to
    " the right message history in case of multiple queries.
    let l:job_conf = {'out_cb': 's:on_out', 'err_cb': 's:on_err', 'close_cb': 's:on_close'}

    call s:send_query(req, l:job_conf)

    " we are not printing from session, but stream tokens one by one
    " So we append prompt here
    let bufnum = bufnr('vim_qna_chat')
    let prompt = strftime("%H:%M:%S Local: ")
    call appendbufline(bufnum, line('$'), prompt)
endfunction

function! s:get_visual_selection()
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]
    return join(lines, "\n")
endfunction

function! s:fmt_question(context, question)
    return "Here's a code snippet: \n\n " . a:context . "\n\n" . a:question
endfunction

function! s:qq_send_message(question)
    let l:context = s:get_visual_selection()
    if l:context == ''
        let l:question = a:question
    else
        let l:question = s:fmt_question(l:context, a:question)
    endif
    let l:message  = {"role": "user", "content": l:question}
    " timestamp and other metadata might get appended here
    let l:message  = s:append_message(l:message)

    call s:print_message(v:true, l:message)
    call s:ask_local()
endfunction

function! s:qq_prepare()
    let l:context = s:get_visual_selection()
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
function s:update_status_line()
  " TODO: show server status, chat id, etc.
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
    else
        let winnum = bufwinnr(l:bufnum)
        if winnum == -1
            silent! execute 'topleft vertical ' . g:qq_width . ' split'
            silent! execute 'buffer ' l:bufnum
        else
            silent! execute winnum . 'wincmd w'
        endif
    endif
    call s:update_status_line()
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
        let l:tstamp = strftime("%H:%M:%S ", a:message['timestamp'])
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

function! s:display_session(session_id)
    call s:load_sessions()
    call s:open_chat()
    let s:current_session = a:session_id

    silent! call deletebufline('%', 1, '$')

    for l:msg in s:sessions[a:session_id].messages
        call s:print_message(v:false, l:msg)
    endfor
    call s:update_status_line()
endfunction

function! s:new_chat()
    call s:start_session()
    call s:display_session(s:current_session)
endfunction

" -----------------------------------------------------------------------------
" basic color scheme setup
function! s:setup_syntax()
    syntax clear

    syntax match localPrompt   "^\d\d:\d\d:\d\d\s*Local:"  nextgroup=restOfLine

    syntax match userTagPrompt "^\d\d:\d\d:\d\d\s*You:"  nextgroup=restOfLine

    syntax match restOfLine ".*$" contained

    highlight localPrompt   cterm=bold gui=bold
    highlight userTagPrompt cterm=bold gui=bold
endfunction

augroup VQQSyntax
    autocmd!
    autocmd BufRead,BufNewFile *vim_qna_chat* call s:setup_syntax()
augroup END

" -----------------------------------------------------------------------------
"  commands and default key mappings
xnoremap <silent> QQ         :<C-u>call <SID>qq_prepare()<CR>
nnoremap <silent> <leader>qq :call      <SID>toggle_chat_window()<CR>

command! -range -nargs=+ QQ call s:qq_send_message(<q-args>)
command!        -nargs=1 QL call s:display_session(<f-args>)
command!        -nargs=0 QN call s:new_chat()
