" Copyright 2024 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_platform')
    finish
endif

let g:autoloaded_vimqq_platform = 1

" TODO: this needs to take platform and vim install dir into account
function! vimqq#platform#path(filename)
    return expand('~/.vim/') . a:filename
endfunction
