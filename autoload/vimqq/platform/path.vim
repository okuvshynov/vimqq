if exists('g:autoloaded_vimqq_platform_path')
    finish
endif
let g:autoloaded_vimqq_platform_path = 1

function! vimqq#platform#path#data_root()
    if vimqq#platform#common#is_nvim()
        return stdpath("data")
    else
        return expand('~/.vim')
    endif
endfunction

function! vimqq#platform#path#join(...)
    return join(a:000, '/')