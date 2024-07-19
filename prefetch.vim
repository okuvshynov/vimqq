" Copyright 2024 Oleksandr Kuvshynov

" -----------------------------------------------------------------------------
" configuration

" how many tokens to generate for each message
let g:qq_max_tokens = get(g:, 'qq_max_tokens', 1024)
" llama.cpp (or compatible) server
let g:qq_server = get(g:, 'qq_server', "http://localhost:8080/")
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

source ui.vim
source chatsdb.vim

let s:ui = g:vqq#UI.new()
let s:chatsdb = g:vqq#ChatsDB.new(s:sessions_file)

" {{{ Utilities, local state
" get or create a new session if there isn't one
function! s:current_session_id()
    if s:current_session == -1
        let s:current_session = s:chatsdb.new_chat()
    endif
    return s:current_session
endfunction

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

function! s:fmt_question(context, question)
    return "Here's a code snippet: \n\n " . a:context . "\n\n" . a:question
endfunction
" }}}

" {{{  Client for llama.cpp server or compatible
let s:Client = {} 

function! s:Client.init() dict
    let l:server = substitute(g:qq_server, '/*$', '', '')
    let self._chat_endpoint   = l:server . '/v1/chat/completions'
    let self._status_endpoint = l:server . '/health'
    let self._callbacks = {} 
    call s:Client._get_status()
endfunction

function s:Client.set_callback(key, fn) dict
    let self._callbacks[a:key] = a:fn
endfunction

function s:Client._on_server_status(status) dict
    if has_key(self._callbacks, 'status_cb')
        call self._callbacks['status_cb'](a:status) 
    endif
endfunction

function s:Client._on_status_exit(exit_status) dict
    if a:exit_status != 0
        call self._on_server_status("unavailable")
    endif
    call timer_start(s:healthcheck_ms, { -> s:Client._get_status() })
endfunction

function s:Client._on_status_out(msg) dict
    let l:status = json_decode(a:msg)
    if empty(l:status)
        call self._on_server_status("unavailable")
    else
        call self._on_server_status(l:status.status)
    endif
endfunction

function s:Client._get_status() dict
    let l:curl_cmd = ["curl", "--max-time", "5", self._status_endpoint]
    let l:job_conf = {
          \ 'out_cb' : {channel, msg   -> self._on_status_out(msg)},
          \ 'exit_cb': {job_id, status -> self._on_status_exit(status)}
    \}

    call s:keep_job(job_start(l:curl_cmd, l:job_conf))
endfunction

function s:Client._send_chat_query(req, job_conf) dict
    let l:json_req  = json_encode(a:req)
    let l:json_req  = substitute(l:json_req, "'", "'\\\\''", "g")

    let l:curl_cmd  = "curl --no-buffer -s -X POST '" . self._chat_endpoint . "'"
    let l:curl_cmd .= " -H 'Content-Type: application/json'"
    let l:curl_cmd .= " -d '" . l:json_req . "'"

    call s:keep_job(job_start(['/bin/sh', '-c', l:curl_cmd], a:job_conf))
endfunction

function! s:Client._on_stream_out(session_id, msg) dict
    if a:msg !~# '^data: '
        return
    endif
    let json_string = substitute(a:msg, '^data: ', '', '')

    let response = json_decode(json_string)
    if has_key(response.choices[0].delta, 'content')
        let next_token = response.choices[0].delta.content
        if has_key(self._callbacks, 'token_cb')
            call self._callbacks['token_cb'](a:session_id, next_token)
        endif
    endif
endfunction

function! s:Client._on_stream_close(session_id)
    call s:chatsdb.partial_done(a:session_id)

    " TODO - need to subscribe to something here as well
    if !s:chatsdb.has_title(a:session_id)
        call self.send_gen_title(a:session_id, s:chatsdb.get_first_message(a:session_id))
    endif
endfunction

function! s:Client._on_err(session_id, msg)
    " TODO: logging
endfunction

function! s:Client._on_title_out(session_id, msg)
    let json_string = substitute(a:msg, '^data: ', '', '')

    let response = json_decode(json_string)
    if has_key(response.choices[0].message, 'content')
        let title = response.choices[0].message.content
        call s:chatsdb.set_title(a:session_id, title)
    endif
endfunction

" warmup query to pre-fill the cache on the server.
" We ask for 0 tokens and ignore the response.
function! s:Client.send_warmup(session_id, question) dict
    let req = {}
    let req.messages     = s:chatsdb.get_messages(a:session_id) + [{"role": "user", "content": a:question}]
    let req.n_predict    = 0
    let req.stream       = v:true
    let req.cache_prompt = v:true

    call self._send_chat_query(req, {})
endfunction

" assumes the last message is already in the session 
function! s:Client.send_chat(session_id) dict
    let req = {}
    let req.messages     = s:chatsdb.get_messages(a:session_id)
    let req.n_predict    = g:qq_max_tokens
    let req.stream       = v:true
    let req.cache_prompt = v:true

    call s:chatsdb.clear_partial(a:session_id)

    let l:job_conf = {
          \ 'out_cb'  : {channel, msg -> self._on_stream_out(a:session_id, msg)}, 
          \ 'err_cb'  : {channel, msg -> self._on_err(a:session_id, msg)},
          \ 'close_cb': {channel      -> self._on_stream_close(a:session_id)}
    \ }

    call self._send_chat_query(req, l:job_conf)
endfunction

" ask for a title we'll use. Uses first message in a chat session
" TODO: this actually pollutes the kv cache for next messages.
function! s:Client.send_gen_title(session_id, message_text)
    let req = {}
    let prompt = "Write a title with a few words summarizing the following paragraph. Reply only with title itself. Use no quotes around it.\n\n"
    let req.messages  = [{"role": "user", "content": prompt . a:message_text}]
    let req.n_predict    = s:qq_title_tokens
    let req.stream       = v:false
    let req.cache_prompt = v:true

    let l:job_conf = {
          \ 'out_cb': {channel, msg -> s:Client._on_title_out(a:session_id, msg)}
    \ }

    call s:Client._send_chat_query(req, l:job_conf)
endfunction

call s:Client.init()

" }}}

call s:Client.set_callback('status_cb', {status -> s:ui.update_statusline(status)})
call s:Client.set_callback('token_cb', {session_id, msg -> [s:chatsdb.append_partial(session_id, msg), s:ui.maybe_append(session_id, msg)][-1]})

" {{{ API for commands
function! s:qq_send_message(question, use_context)
    let l:context = s:ui.get_visual_selection()
    if a:use_context
        let l:question = s:fmt_question(l:context, a:question)
    else
        let l:question = a:question
    endif
    let l:message  = {"role": "user", "content": l:question}
    let l:session_id = s:current_session_id() 
    " timestamp and other metadata might get appended here
    let l:message    = s:chatsdb.append_message(l:session_id, l:message)

    call s:qq_show_chat(l:session_id)
    call s:ui.display_prompt()
    call s:Client.send_chat(l:session_id)
endfunction

function! s:qq_warmup()
    let l:context = s:ui.get_visual_selection()
    if !empty(l:context)
        call s:Client.send_warmup(s:current_session_id(), s:fmt_question(l:context, ""))
        call feedkeys(":'<,'>QQ ", 'n')
    endif
endfunction

function! s:qq_toggle_window()
    call s:ui.toggle()
endfunction

function! s:qq_new_chat()
    call s:qq_show_chat(s:chatsdb.new_chat())
endfunction

function! s:qq_show_chat_list()
    let l:titles = []
    let l:session_id_map = {}

    for item in s:chatsdb.get_ordered_chats()
        let l:sep = ' '
        if s:current_session == item.id
            let l:selected_line = len(titles) + 1
            let l:sep = '>'
        endif

        call add(l:titles, strftime(g:qq_timefmt . l:sep . item.title, item.time))
        let l:session_id_map[len(titles)] = item.id
    endfor

    call s:ui.open_window()

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

    function! ActivateChat() closure
        call s:qq_show_chat(l:session_id_map[line('.')])
    endfunction
    nnoremap <silent> <buffer> <CR> :call ActivateChat()<CR>
    nnoremap <silent> <buffer> q    :call <SID>qq_toggle_window()<CR>
endfunction

function! s:qq_show_chat(session_id)
    call s:ui.open_window()

    let s:current_session = a:session_id

    mapclear <buffer>
    setlocal modifiable
    silent! call deletebufline('%', 1, '$')

    for l:message in s:chatsdb.get_messages(a:session_id)
        call s:ui.append_message(v:false, l:message)
    endfor

    " display streamed partial response
    let l:partial = s:chatsdb.get_partial(a:session_id)
    if !empty(l:partial)
        let l:msg = strftime(g:qq_timefmt . " Local: ") . l:partial
        let l:lines = split(l:msg, '\n')
        call append(line('$'), l:lines)
    endif

    nnoremap <silent> <buffer> q  :call <SID>qq_show_chat_list()<CR>
endfunction

" }}}

" -----------------------------------------------------------------------------
"  commands and default key mappings
xnoremap <silent> QQ :<C-u>call <SID>qq_warmup()<CR>

command! -range -nargs=+ QQ  call s:qq_send_message(<q-args>, v:true)
command!        -nargs=+ Q   call s:qq_send_message(<q-args>, v:false)
command!        -nargs=1 QL  call s:qq_show_chat(<f-args>)
command!        -nargs=0 QN  call s:qq_new_chat()
command!        -nargs=0 QP  call s:qq_show_chat_list()
command!        -nargs=0 QT  call s:qq_toggle_window()
