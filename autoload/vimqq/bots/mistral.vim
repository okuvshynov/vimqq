" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_mistral_module')
    finish
endif

let g:autoloaded_vimqq_mistral_module = 1

function! vimqq#bots#mistral#new(config = {}) abort
    let impl = vimqq#api#mistral_api#new()
    return vimqq#client#new(impl, a:config)
endfunction
