" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_deepseek_module')
    finish
endif

let g:autoloaded_vimqq_deepseek_module = 1

function! vimqq#bots#deepseek#new(config = {}) abort
    let impl = vimqq#api#deepseek_api#new({})
    return vimqq#bots#bot#new(impl, a:config)
endfunction
