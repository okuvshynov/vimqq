if exists('g:autoloaded_vimqq_metrics')
    finish
endif

let s:metrics_file = strftime('%Y%m%d_%H%M%S_session_metrics.json')

let g:autoloaded_vimqq_metrics = 1

let s:metrics = {}
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
            " TODO: this tracking is wrong in case of non-empty queue
            " as we would unlet the start point for both messages
            call vimqq#log#info('token for chat with no start point.')
        endif
    endif
endfunction

function! vimqq#metrics#inc(name, value=1)
    if !has_key(s:metrics, a:name)
        let s:metrics[a:name] = 0
    endif
    let s:metrics[a:name] += a:value
endfunction

function! vimqq#metrics#get(name)
    return get(s:metrics, a:name, 0)
endfunction

function! vimqq#metrics#save()
    let metrics_json = json_encode(s:metrics)
    call writefile([metrics_json], vimqq#platform#path#data(s:metrics_file))
endfunction

" Save every N seconds + at exit
autocmd VimLeavePre * call vimqq#metrics#save()
" Configurable metrics dump interval
let s:save_interval = get(g:, 'vqq_metrics_dump_interval', 600)
call timer_start(s:save_interval * 1000, {t -> vimqq#metrics#save()}, {'repeat': -1})
