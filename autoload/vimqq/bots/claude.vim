" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_claude_module')
    finish
endif

let g:autoloaded_vimqq_claude_module = 1

function! vimqq#bots#claude#new(config = {}) abort
    let l:impl = vimqq#api#anthropic_api#new()
    return vimqq#client#new(l:impl, a:config)
endfunction
