" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_claude_module')
    finish
endif

let g:autoloaded_vimqq_claude_module = 1

function! vimqq#bots#claude#new(config = {}) abort
    let l:impl = vimqq#api#anthropic_api#new()
    let l:client = vimqq#client#new(l:impl, a:config)

    let l:client.toolset = vimqq#tools#toolset#new()
    return l:client
endfunction
