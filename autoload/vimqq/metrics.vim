if exists('g:autoloaded_vimqq_metrics')
    finish
endif

let g:autoloaded_vimqq_metrics = 1

let s:metrics = {}

" tracking how many pieces of messages we received
" overall. Move to 'stats'?
function! vimqq#metrics#inc(name)
    if !has_key(s:metrics, a:name)
        let s:metrics[a:name] = 0
    endif
    let s:metrics[a:name] += 1
endfunction

function! vimqq#metrics#get(name)
    return get(s:metrics, a:name, 0)
endfunction
