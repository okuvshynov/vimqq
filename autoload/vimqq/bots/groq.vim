" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_groq_module')
    finish
endif

let g:autoloaded_vimqq_groq_module = 1

function! vimqq#bots#groq#new(config = {}) abort
    let impl = vimqq#api#groq_api#new()
    return vimqq#bots#bot#new(impl, a:config)
endfunction
