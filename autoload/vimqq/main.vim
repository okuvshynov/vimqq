if exists('g:autoloaded_vimqq_main')
    finish
endif

let g:autoloaded_vimqq_main = 1

" Single controller instance
let s:controller = v:null

" Creating new instance of vimqq resetting all state.
function! vimqq#main#setup()
    let s:controller = vimqq#controller#new()
    call s:controller.init()
endfunction

function! vimqq#main#notify(event, context) abort
    return s:controller.notify(a:event, a:context)
endfunction

" Core controller functions
function! vimqq#main#send_message(force_new_chat, question, context=v:null, use_index=v:false, use_tools=v:false)
    call s:controller.send_message(a:force_new_chat, a:question, a:context, a:use_index, a:use_tools)
endfunction

" returns true if warmup was started, and false if not (for example, tagged
" bot doesn't support warmup or there was an error)
function! vimqq#main#send_warmup(force_new_chat, question, context=v:null)
    return s:controller.send_warmup(a:force_new_chat, a:question, a:context)
endfunction

function! vimqq#main#show_list()
    call s:controller.show_list()
endfunction

function! vimqq#main#show_chat(chat_id)
    call s:controller.show_chat(a:chat_id)
endfunction

function! vimqq#main#init() abort
    " Just to autoload
endfunction

function! vimqq#main#fzf() abort
    call s:controller.fzf()
endfunction

" Command handlers
function! vimqq#main#qq(message) abort range
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    call vimqq#main#send_message(v:false, a:message, context)
endfunction

function! vimqq#main#qqn(message) abort range
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    call vimqq#main#send_message(v:true, a:message, context)
endfunction

function! vimqq#main#qqi(message) abort range
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    call vimqq#main#send_message(v:true, a:message, context, v:true)
endfunction

function! vimqq#main#qi(message) abort
    call vimqq#main#send_message(v:true, a:message, v:null, v:true)
endfunction

function! vimqq#main#qqt(message) abort range
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    call vimqq#main#send_message(v:true, a:message, context, v:false, v:true)
endfunction

function! vimqq#main#qt(message) abort
    call vimqq#main#send_message(v:true, a:message, v:null, v:false, v:true)
endfunction


function! vimqq#main#q(message) abort
    call vimqq#main#send_message(v:false, a:message)
endfunction

function! vimqq#main#qn(message) abort
    call vimqq#main#send_message(v:true, a:message)
endfunction

function! vimqq#main#dispatch_new(count, line1, line2, args) abort
    if a:count ==# -1
        call vimqq#main#qn(a:args)
    else
        execute a:line1 . ',' . a:line2 . 'call vimqq#main#qqn(a:args)'
    endif
endfunction

function! vimqq#main#dispatch(count, line1, line2, args) abort
    if a:count ==# -1
        call vimqq#main#q(a:args)
    else
        execute a:line1 . ',' . a:line2 . 'call vimqq#main#qq(a:args)'
    endif
endfunction

function! vimqq#main#dispatch_index(count, line1, line2, args) abort
    if a:count ==# -1
        call vimqq#main#qi(a:args)
    else
        execute a:line1 . ',' . a:line2 . 'call vimqq#main#qqi(a:args)'
    endif
endfunction

function! vimqq#main#dispatch_tools(count, line1, line2, args) abort
    if a:count ==# -1
        call vimqq#main#qt(a:args)
    else
        execute a:line1 . ',' . a:line2 . 'call vimqq#main#qqt(a:args)'
    endif
endfunction

call vimqq#main#setup()
