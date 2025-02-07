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

" These functions are called from vimqq#cmd module.
" They forward the commands to current s:controller instance.

function! vimqq#main#send_message(force_new_chat, question, context=v:null, use_index=v:false)
    call s:controller.send_message(a:force_new_chat, a:question, a:context, a:use_index)
endfunction

function! vimqq#main#send_warmup(force_new_chat, question, context=v:null)
    call s:controller.send_warmup(a:force_new_chat, a:question, a:context)
endfunction

function! vimqq#main#gen_ref(question)
    call s:controller.send_crawl_ref(a:question)
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

call vimqq#main#setup()
