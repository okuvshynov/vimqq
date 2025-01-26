" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_log')
    finish
endif

let g:autoloaded_vimqq_log = 1

let g:vqq_log_file = get(g:, 'vqq_log_file', vimqq#platform#path#log('vimqq.log'))
let g:vqq_log_level = get(g:, 'vqq_log_level', 'INFO')
let g:vqq_log_format = get(g:, 'vqq_log_format', '%Y-%m-%d %H:%M:%S ')

let s:log_levels = {
    \ 'DEBUG': 0,
    \ 'INFO': 1,
    \ 'WARNING': 2,
    \ 'ERROR': 3,
    \ 'NONE': 4
\ }

function s:_log_impl(level, message)
    if s:log_levels[a:level] >= s:log_levels[g:vqq_log_level]
        let message = a:level[0] . strftime(g:vqq_log_format) . a:message
        call writefile([message], g:vqq_log_file, "a")
        let level_log_file = g:vqq_log_file . "." . a:level
        call writefile([message], level_log_file, "a")
    endif
endfunction

function! vimqq#log#error(message)
    call s:_log_impl('ERROR', a:message)
endfunction

function! vimqq#log#info(message)
    call s:_log_impl('INFO', a:message)
endfunction

function! vimqq#log#debug(message)
    call s:_log_impl('DEBUG', a:message)
endfunction

function! vimqq#log#warning(message)
    call s:_log_impl('WARNING', a:message)
endfunction
