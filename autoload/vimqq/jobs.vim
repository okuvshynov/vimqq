if exists('g:autoloaded_vimqq_utils')
    finish
endif
let g:autoloaded_vimqq_utils = 1

function! vimqq#jobs#start(command, config)
    if vimqq#platform#common#is_nvim()
        return vimqq#platform#jobs#nvim#start(a:command, a:config)
    else
        return vimqq#platform#jobs#vim#start(a:command, a:config)
    endif
endfunction
