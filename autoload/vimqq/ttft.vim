if exists('g:autoloaded_vimqq_ttft')
    finish
endif

let g:autoloaded_vimqq_ttft = 1

let s:latencies = {}

function! vimqq#ttft#user_started_waiting(chat_id) abort
    if exists('*reltime')
        let s:latencies[a:chat_id] = reltime()
    endif
endfunction

function! vimqq#ttft#first_token(chat_id) abort
    if exists('*reltime')
        if has_key(s:latencies, a:chat_id)
            let latency = reltimefloat(reltime(s:latencies[a:chat_id]))
            let ttft = printf('client: ttft = %.3f s', latency)
            call vimqq#sys_msg#info(a:chat_id, ttft)
        else
            call vimqq#log#warning('token for chat with no start point.')
        endif
    endif
endfunction

function! vimqq#ttft#completion(chat_id) abort
    if exists('*reltime')
        if has_key(s:latencies, a:chat_id)
            let latency = reltimefloat(reltime(s:latencies[a:chat_id]))
            let latency = printf('client: generation = %.3f s', latency)
            call vimqq#sys_msg#info(a:chat_id, latency)
            unlet s:latencies[a:chat_id]
        else
            call vimqq#log#warning('token for chat with no start point.')
        endif
    endif
endfunction
