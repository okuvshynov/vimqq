" This module is parsing commands and forwards them to the 
" appropriate vimqq#main command.
" It is a stateless module, other than autoload guard.

if exists('g:autoloaded_vimqq_cmd')
    finish
endif

let g:autoloaded_vimqq_cmd = 1

function! vimqq#cmd#fzf() abort
    call vimqq#main#fzf()
endfunction

function! vimqq#cmd#show_list() abort
    call vimqq#main#show_list()
endfunction

function! vimqq#cmd#init() abort
    call vimqq#main#init()
endfunction

function! vimqq#cmd#qq(message) abort range
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    call vimqq#main#send_message(v:false, a:message, context)
endfunction

function! vimqq#cmd#qqn(message) abort range
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    call vimqq#main#send_message(v:true, a:message, context)
endfunction

function! vimqq#cmd#qqi(message) abort range
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    call vimqq#main#send_message(v:true, a:message, context, v:true)
endfunction

function! vimqq#cmd#qi(message) abort
    call vimqq#main#send_message(v:true, a:message, v:null, v:true)
endfunction

function! vimqq#cmd#q(message) abort
    call vimqq#main#send_message(v:false, a:message)
endfunction

function! vimqq#cmd#qn(message) abort
    call vimqq#main#send_message(v:true, a:message)
endfunction

function! vimqq#cmd#qref(message) abort
    call vimqq#main#gen_ref(a:message)
endfunction

function! vimqq#cmd#dispatch_new(count, line1, line2, args) abort
    if a:count ==# -1
        " No range was provided
        call vimqq#cmd#qn(a:args)
    else
        " Range was provided, pass the line numbers
        execute a:line1 . ',' . a:line2 . 'call vimqq#cmd#qqn(a:args)'
    endif
endfunction

function! vimqq#cmd#dispatch(count, line1, line2, args) abort
    if a:count ==# -1
        " No range was provided
        call vimqq#cmd#q(a:args)
    else
        " Range was provided, pass the line numbers
        execute a:line1 . ',' . a:line2 . 'call vimqq#cmd#qq(a:args)'
    endif
endfunction

function! vimqq#cmd#dispatch_index(count, line1, line2, args) abort
    if a:count ==# -1
        " No range was provided
        call vimqq#cmd#qi(a:args)
    else
        " Range was provided, pass the line numbers
        execute a:line1 . ',' . a:line2 . 'call vimqq#cmd#qqi(a:args)'
    endif
endfunction
