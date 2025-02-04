if exists('g:autoloaded_vimqq_metrics')
    finish
endif

let g:autoloaded_vimqq_metrics = 1

let s:latencies = {}

function! vimqq#metrics#user_started_waiting(chat_id) abort
    if exists('*reltime')
        let s:latencies[a:chat_id] = reltime()
    endif
endfunction

function! vimqq#metrics#first_token(chat_id) abort
    if exists('*reltime')
        if has_key(s:latencies, a:chat_id)
            let latency = reltimefloat(reltime(s:latencies[a:chat_id]))
            call vimqq#log#info(printf('TTFT %.3f s', latency))
            unlet s:latencies[a:chat_id]
        else
            call vimqq#log#warning('token for chat with no start point.')
        endif
    endif
endfunction
