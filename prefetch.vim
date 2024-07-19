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

" {{{ Utilities, local state
" get or create a new session if there isn't one
function! s:current_session_id()
    if s:current_session == -1
        let s:current_session = s:Chats.new_chat()
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

" {{{  Client for llama.cpp server or compatible
let s:Client = {} 

function! s:Client.init() dict
    let l:server = substitute(g:qq_server, '/*$', '', '')
    let self._chat_endpoint   = l:server . '/v1/chat/completions'
    let self._status_endpoint = l:server . '/health'
    let self._status    = "unknown"
    let self._callbacks = {} 
    call s:Client._get_status()
endfunction

function s:Client.set_callback(key, fn) dict
    let self._callbacks[a:key] = a:fn
endfunction

function s:Client._on_server_status(status) dict
    if a:status != self._status
        let self._server_status = a:status
        if has_key(self._callbacks, 'status_cb')
            call self._callbacks['status_cb'](a:status) 
        endif
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
    call s:Chats.partial_done(a:session_id)

    " TODO - need to subscribe to something here as well
    if !s:Chats.has_title(a:session_id)
        call self.send_gen_title(a:session_id, s:Chats.get_first_message(a:session_id))
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
        call s:Chats.set_title(a:session_id, title)
    endif
endfunction

" warmup query to pre-fill the cache on the server.
" We ask for 0 tokens and ignore the response.
function! s:Client.send_warmup(session_id, question) dict
    let req = {}
    let req.messages     = s:Chats.get_messages(a:session_id) + [{"role": "user", "content": a:question}]
    let req.n_predict    = 0
    let req.stream       = v:true
    let req.cache_prompt = v:true

    call self._send_chat_query(req, {})
endfunction

" assumes the last message is already in the session 
function! s:Client.send_chat(session_id) dict
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

" {{{ User interface, buffer/window manipulation
let s:UI = {}

function! s:UI.update_statusline(status) dict
    let g:qq_server_status = a:status
    redrawstatus!
endfunction

function! s:UI.open_window() dict
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

function! s:UI.append_message(open_chat, message) dict
    if a:open_chat
        call self.open_window()
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

function! s:UI.maybe_append(session_id, token) dict
    if s:current_session == a:session_id
        let l:bufnum    = bufnr('vim_qna_chat')
        let l:curr_line = getbufoneline(bufnum, '$')
        silent! call setbufline(l:bufnum, '$', split(l:curr_line . a:token . "\n", '\n'))
    endif
endfunction

function! s:UI.display_prompt() dict
    "TODO: do that only if chat is open, not selection view
    let l:bufnum  = bufnr('vim_qna_chat')
    let l:msg     = strftime(g:qq_timefmt . " Local: ")
    let l:lines   = split(l:msg, '\n')
    call appendbufline(l:bufnum, line('$'), l:lines)
endfunction

function! s:UI.toggle() dict
    let bufnum = bufnr('vim_qna_chat')
    if bufnum == -1
        call self.open_window()
    else
        let l:winid = bufwinid('vim_qna_chat')
        if l:winid != -1
            call win_gotoid(l:winid)
            silent! execute 'hide'
        else
            call self.open_window()
        endif
    endif
endfunction

function! s:UI.get_visual_selection() dict
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


" }}}

call s:Client.set_callback('status_cb', {status -> s:UI.update_statusline(status)})
call s:Client.set_callback('token_cb', {session_id, msg -> [s:Chats.append_partial(session_id, msg), s:UI.maybe_append(session_id, msg)][-1]})

" {{{ API for commands
function! s:qq_send_message(question, use_context)
    let l:context = s:UI.get_visual_selection()
    if a:use_context
        let l:question = s:fmt_question(l:context, a:question)
    else
        let l:question = a:question
    endif
    let l:message  = {"role": "user", "content": l:question}
    let l:session_id = s:current_session_id() 
    " timestamp and other metadata might get appended here
    let l:message    = s:Chats.append_message(l:session_id, l:message)

    call s:UI.append_message(v:true, l:message)
    call s:UI.display_prompt()
    call s:Client.send_chat(l:session_id)
endfunction

function! s:qq_warmup()
    let l:context = s:get_visual_selection()
    if !empty(l:context)
        call s:Client.send_warmup(s:current_session_id(), s:fmt_question(l:context, ""))
    endif
    call feedkeys(":'<,'>QQ ", 'n')
endfunction

function! s:qq_toggle_window()
    call s:UI.toggle()
endfunction

function! s:qq_new_chat()
    call s:qq_show_chat(s:Chats.new_chat())
endfunction

function! s:qq_show_chat_list()
    let l:titles = []
    let l:session_id_map = {}

    for item in s:Chats.get_ordered_chats()
        let l:sep = ' '
        if s:current_session == item.id
            let l:selected_line = len(titles) + 1
            let l:sep = '*'
        endif

        call add(l:titles, strftime(g:qq_timefmt . l:sep . item.title, item.time))
        let l:session_id_map[len(titles)] = item.id
    endfor

    call s:UI.open_window()

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
    call s:UI.open_window()

    let s:current_session = a:session_id

    mapclear <buffer>
    setlocal modifiable
    silent! call deletebufline('%', 1, '$')

    for l:message in s:Chats.get_messages(a:session_id)
        call s:UI.append_message(v:false, l:message)
    endfor

    " display streamed partial response
    let l:partial = s:Chats.get_partial(a:session_id)
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
