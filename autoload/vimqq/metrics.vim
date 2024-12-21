if exists('g:autoloaded_vimqq_metrics')
    finish
endif

let s:metrics_file = strftime('%Y%m%d_%H%M%S_session_metrics.json')

let g:autoloaded_vimqq_metrics = 1

let s:metrics = {}

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
" TODO: make configurable
let s:save_interval = 600
call timer_start(s:save_interval * 1000, {t -> vimqq#metrics#save()}, {'repeat': -1})
