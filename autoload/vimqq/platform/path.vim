" Copyright 2024 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_path')
    finish
endif

let g:autoloaded_vimqq_path = 1

function! vimqq#platform#path#log(filename)
    if has('nvim')
        return stdpath("data") . '/' . a:filename
    else
        return expand('~/.vim/') . a:filename
    endif
endfunction

function! vimqq#platform#path#data(filename)
    let path = ''
    if has('nvim')
        let path = stdpath("data") . '/' . a:filename
    else
        let path = expand('~/.vim/') . a:filename
    endif
    
    " Create directory if it doesn't exist and the path looks like a directory
    if a:filename !~# '\.\w\+$'
        if !isdirectory(path)
            call mkdir(path, 'p')
        endif
    endif
    
    return path
endfunction
