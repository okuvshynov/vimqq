if exists('g:autoloaded_vimqq_platform_common')
    finish
endif
let g:autoloaded_vimqq_platform_common = 1

function! vimqq#platform#common#is_nvim()
    return has('nvim')
endfunction