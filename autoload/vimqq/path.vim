" Copyright 2024 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_path')
    finish
endif

let g:autoloaded_vimqq_path = 1

function! vimqq#path#log(filename)
    if has('nvim')
        return stdpath("log") . '/' . a:filename
    else
        return expand('~/.vim/') . a:filename
    endif
endfunction

function! vimqq#path#data(filename)
    if has('nvim')
        return stdpath("data") . '/' . a:filename
    else
        return expand('~/.vim/') . a:filename
    endif
endfunction