" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_groq_module')
    finish
endif

let g:autoloaded_vimqq_groq_module = 1

function! vimqq#bots#groq#new(config = {}) abort
    let l:impl = vimqq#api#groq_api#new()
    return vimqq#client#new(l:impl, a:config)
endfunction
