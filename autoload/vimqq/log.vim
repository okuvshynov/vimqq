" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_log')
    finish
endif

let g:autoloaded_vimqq_log = 1

let g:vqq_log_file = get(g:, 'vqq_log_file', vimqq#path#log('vimqq.log'))
let g:vqq_log_level = get(g:, 'vqq_log_level', 'INFO')

let s:log_levels = {
    \ 'DEBUG': 0,
    \ 'INFO': 1,
    \ 'ERROR': 2,
    \ 'NONE': 3
\ }

function s:_log_impl(level, message)
    if s:log_levels[a:level] >= s:log_levels[g:vqq_log_level]
        let l:message = a:level[0] . strftime("%Y-%m-%d %H:%M:%S ") . a:message
        call writefile([l:message], g:vqq_log_file, "a")
    endif
endfunction

function! vimqq#log#error(message)
    call s:_log_impl('ERROR', a:message)
    echoe a:message
endfunction

function! vimqq#log#info(message)
    call s:_log_impl('INFO', a:message)
endfunction

function! vimqq#log#debug(message)
    call s:_log_impl('DEBUG', a:message)
endfunction
