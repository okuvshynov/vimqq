" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_sys_msg')
    finish
endif

let g:autoloaded_vimqq_sys_msg = 1

" sys messages are chat-specific, thus, they need to be
" added in the context where we know which chat they belong to.

function! vimqq#sys_msg#log(level, chat_id, msg) abort
    let args = {'chat_id': a:chat_id, 'text': a:msg, 'level': a:level}
    call vimqq#events#notify('system_message', args)
endfunction

function! vimqq#sys_msg#info(chat_id, msg) abort
    call vimqq#sys_msg#log('info', a:chat_id, a:msg)
endfunction

function! vimqq#sys_msg#warning(chat_id, msg) abort
    call vimqq#sys_msg#log('warning', a:chat_id, a:msg)
endfunction

function! vimqq#sys_msg#error(chat_id, msg) abort
    call vimqq#sys_msg#log('error', a:chat_id, a:msg)
endfunction
