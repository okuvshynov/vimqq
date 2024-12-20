" Copyright 2024 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_path')
    finish
endif

let g:autoloaded_vimqq_path = 1

function! vimqq#path#log(filename)
    return vimqq#platform#path#join(vimqq#platform#path#data_root(), a:filename)
endfunction

function! vimqq#path#data(filename)
    return vimqq#platform#path#join(vimqq#platform#path#data_root(), a:filename)
endfunction
