" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_log')
    finish
endif

let g:autoloaded_vimqq_log = 1

let g:vqq_log_file = get(g:, 'vqq_log_file', expand("~/.vim/vimqq.log"))

function s:_log_impl(level, message)
    let l:message = a:level . strftime("%Y-%m-%d %H:%M:%S ") . a:message
    call writefile([l:message], g:vqq_log_file, "a")
endfunction

function! vimqq#log#error(message)
    call s:_log_impl('E', a:message)
    echoe a:message
endfunction

function! vimqq#log#info(message)
    call s:_log_impl('I', a:message)
endfunction

