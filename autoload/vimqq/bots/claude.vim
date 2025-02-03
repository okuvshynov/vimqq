" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_claude_module')
    finish
endif

let g:autoloaded_vimqq_claude_module = 1

function! vimqq#bots#claude#new(config = {}) abort
    let impl = vimqq#api#anthropic_api#new()
    let client = vimqq#bots#bot#new(impl, a:config)

    return client
endfunction
