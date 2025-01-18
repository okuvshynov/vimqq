if exists('g:autoloaded_vimqq_api')
    finish
endif

let g:autoloaded_vimqq_api = 1

function! vimqq#api#fzf() abort
    call vimqq#main#fzf()
endfunction

function! vimqq#api#show_list() abort
    call vimqq#main#show_list()
endfunction

function! vimqq#api#init() abort
    call vimqq#main#init()
endfunction

function! vimqq#api#fork_chat(args) abort
    call vimqq#main#fork_chat(a:args)
endfunction

function! vimqq#api#qq(message) abort range
    call vimqq#log#debug('qq: sending message')
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    call vimqq#main#send_message(v:false, a:message, context)
endfunction

function! vimqq#api#qqn(message) abort range
    call vimqq#log#debug('qqn: sending message')
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    call vimqq#main#send_message(v:true, a:message, context)
endfunction

function! vimqq#api#qqi(message) abort range
    call vimqq#log#debug('qqi: sending message')
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    call vimqq#main#send_message(v:true, a:message, context, v:true)
endfunction

function! vimqq#api#qi(message) abort
    call vimqq#log#debug('qi: sending message')
    call vimqq#main#send_message(v:true, a:message, v:null, v:true)
endfunction

function! vimqq#api#q(message) abort
    call vimqq#log#debug('q: sending message')
    call vimqq#main#send_message(v:false, a:message)
endfunction

function! vimqq#api#qn(message) abort
    call vimqq#log#debug('qn: sending message')
    call vimqq#main#send_message(v:true, a:message)
endfunction

function! vimqq#api#dispatch_new(count, line1, line2, args) abort
    call vimqq#log#info('dispatching')
    if a:count ==# -1
        " No range was provided
        call vimqq#api#qn(a:args)
    else
        " Range was provided, pass the line numbers
        execute a:line1 . ',' . a:line2 . 'call vimqq#api#qqn(a:args)'
    endif
endfunction

function! vimqq#api#dispatch(count, line1, line2, args) abort
    call vimqq#log#info('dispatching')
    if a:count ==# -1
        " No range was provided
        call vimqq#api#q(a:args)
    else
        " Range was provided, pass the line numbers
        execute a:line1 . ',' . a:line2 . 'call vimqq#api#qq(a:args)'
    endif
endfunction

function! vimqq#api#dispatch_index(count, line1, line2, args) abort
    call vimqq#log#info('dispatching')
    if a:count ==# -1
        " No range was provided
        call vimqq#api#qi(a:args)
    else
        " Range was provided, pass the line numbers
        execute a:line1 . ',' . a:line2 . 'call vimqq#api#qqi(a:args)'
    endif
endfunction
