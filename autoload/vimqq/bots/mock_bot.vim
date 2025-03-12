" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_bots_mock')
    finish
endif

let g:autoloaded_vimqq_bots_mock = 1

function! vimqq#bots#mock_bot#new(config = {}) abort
    let impl = vimqq#api#mock_api#new({})
    let bot  = vimqq#bots#bot#new(impl, a:config)
    return bot
endfunction

