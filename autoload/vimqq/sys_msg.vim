" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_sys_msg')
    finish
endif

let g:autoloaded_vimqq_sys_msg = 1

function! s:create_msg(type, chat_id, msg) abort
    call vimqq#events#notify('system_message', {'chat_id': a:chat_id, 'content': a:msg, 'type': a:type})
endfunction

function! vimqq#sys_msg#info(chat_id, msg) abort
    call s:create_msg('info', a:chat_id, a:msg)
endfunction

function! vimqq#sys_msg#warning(chat_id, msg) abort
    call s:create_msg('warning', a:chat_id, a:msg)
endfunction

function! vimqq#sys_msg#error(chat_id, msg) abort
    call s:create_msg('error', a:chat_id, a:msg)
endfunction
