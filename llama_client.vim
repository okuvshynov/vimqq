" llama.cpp (or compatible) server
let g:qq_server = get(g:, 'qq_server', "http://localhost:8080/")

let g:vqq#LlamaClient = {} 

" cleanup dead async jobs if list is longer than this
let s:n_jobs_cleanup = 32
" delay between healthchecks
let s:healthcheck_ms   = 10000
" auto-generated title max length
let s:qq_title_tokens  = 16

" Dead jobs are getting cleaned up after list goes over n_jobs_cleanup
let s:active_jobs = []

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


function! g:vqq#LlamaClient.new() dict
    let l:instance = copy(self)
    let l:server = substitute(g:qq_server, '/*$', '', '')
    let l:instance._chat_endpoint   = l:server . '/v1/chat/completions'
    let l:instance._status_endpoint = l:server . '/health'
    let l:instance._callbacks = {} 
    call l:instance._get_status()

    return l:instance
endfunction

function g:vqq#LlamaClient.set_callback(key, fn) dict
    let self._callbacks[a:key] = a:fn
endfunction

function g:vqq#LlamaClient._on_server_status(status) dict
    if has_key(self._callbacks, 'status_cb')
        call self._callbacks['status_cb'](a:status) 
    endif
endfunction

function g:vqq#LlamaClient._on_status_exit(exit_status) dict
    if a:exit_status != 0
        call self._on_server_status("unavailable")
    endif
    call timer_start(s:healthcheck_ms, { -> self._get_status() })
endfunction

function g:vqq#LlamaClient._on_status_out(msg) dict
    let l:status = json_decode(a:msg)
    if empty(l:status)
        call self._on_server_status("unavailable")
    else
        call self._on_server_status(l:status.status)
    endif
endfunction

function g:vqq#LlamaClient._get_status() dict
    let l:curl_cmd = ["curl", "--max-time", "5", self._status_endpoint]
    let l:job_conf = {
          \ 'out_cb' : {channel, msg   -> self._on_status_out(msg)},
          \ 'exit_cb': {job_id, status -> self._on_status_exit(status)}
    \}

    call s:keep_job(job_start(l:curl_cmd, l:job_conf))
endfunction

function g:vqq#LlamaClient._send_chat_query(req, job_conf) dict
    let l:json_req  = json_encode(a:req)
    let l:json_req  = substitute(l:json_req, "'", "'\\\\''", "g")

    let l:curl_cmd  = "curl --no-buffer -s -X POST '" . self._chat_endpoint . "'"
    let l:curl_cmd .= " -H 'Content-Type: application/json'"
    let l:curl_cmd .= " -d '" . l:json_req . "'"

    call s:keep_job(job_start(['/bin/sh', '-c', l:curl_cmd], a:job_conf))
endfunction

function! g:vqq#LlamaClient._on_stream_out(session_id, msg) dict
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

function! g:vqq#LlamaClient._on_stream_close(session_id)
    if has_key(self._callbacks, 'stream_done_cb')
        call self._callbacks['stream_done_cb'](a:session_id)
    endif
endfunction

function! g:vqq#LlamaClient._on_err(session_id, msg)
    " TODO: logging
endfunction

function! g:vqq#LlamaClient._on_title_out(session_id, msg)
    let json_string = substitute(a:msg, '^data: ', '', '')

    let response = json_decode(json_string)
    if has_key(response.choices[0].message, 'content')
        let title = response.choices[0].message.content
        if has_key(self._callbacks, 'title_done_cb')
            call self._callbacks['title_done_cb'](a:session_id, title)
        endif
    endif
endfunction

" warmup query to pre-fill the cache on the server.
" We ask for 0 tokens and ignore the response.
function! g:vqq#LlamaClient.send_warmup(session_id, messages) dict
    let req = {}
    let req.messages     = a:messages
    let req.n_predict    = 0
    let req.stream       = v:true
    let req.cache_prompt = v:true

    call self._send_chat_query(req, {})
endfunction

" assumes the last message is already in the session 
function! g:vqq#LlamaClient.send_chat(session_id, messages) dict
    let req = {}
    let req.messages     = a:messages
    let req.n_predict    = g:qq_max_tokens
    let req.stream       = v:true
    let req.cache_prompt = v:true


    let l:job_conf = {
          \ 'out_cb'  : {channel, msg -> self._on_stream_out(a:session_id, msg)}, 
          \ 'err_cb'  : {channel, msg -> self._on_err(a:session_id, msg)},
          \ 'close_cb': {channel      -> self._on_stream_close(a:session_id)}
    \ }

    call self._send_chat_query(req, l:job_conf)
endfunction

" ask for a title we'll use. Uses first message in a chat session
" TODO: this actually pollutes the kv cache for next messages.
function! g:vqq#LlamaClient.send_gen_title(session_id, message_text) dict
    let req = {}
    let prompt = "Write a title with a few words summarizing the following paragraph. Reply only with title itself. Use no quotes around it.\n\n"
    let req.messages  = [{"role": "user", "content": prompt . a:message_text}]
    let req.n_predict    = s:qq_title_tokens
    let req.stream       = v:false
    let req.cache_prompt = v:true

    let l:job_conf = {
          \ 'out_cb': {channel, msg -> self._on_title_out(a:session_id, msg)}
    \ }

    call self._send_chat_query(req, l:job_conf)
endfunction
