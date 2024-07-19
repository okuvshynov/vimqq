" Copyright 2024 Oleksandr Kuvshynov

" -----------------------------------------------------------------------------
" configuration

" how many tokens to generate for each message
let g:qq_max_tokens = get(g:, 'qq_max_tokens', 1024)
" format to use for datetime
let g:qq_timefmt = get(g:, 'qq_timefmt', "%Y-%m-%d %H:%M:%S ")

" -----------------------------------------------------------------------------
" script-level constants 

" should each chat have its own file?
let s:chats_file    = expand('~/.vim/qq_chats.json')

" -----------------------------------------------------------------------------
" script-level mutable state

" this is the active chat id. New queries would go to this chat by default
let s:current_chat = -1 
" latest healthcheck result. global so that statusline can access it

function! s:current_chat_id()
    if s:current_chat == -1
        let s:current_chat = s:chatsdb.new_chat()
    endif
    return s:current_chat
endfunction

function! s:fmt_question(context, question)
    return "Here's a code snippet: \n\n " . a:context . "\n\n" . a:question
endfunction

source ui.vim
source chatsdb.vim
source llama_client.vim

let s:ui = g:vqq#UI.new()
let s:chatsdb = g:vqq#ChatsDB.new(s:chats_file)
let s:client = g:vqq#LlamaClient.new()

" -----------------------------------------------------------------------------
" Setting up wiring between modules

" When server updates health status, we update status line
call s:client.set_cb('status_cb', {status -> s:ui.update_statusline(status)})

" When server produces new streamed token, we update db and maybe update ui, 
" if the chat we show is the one updated
function! s:_on_token_done(chat_id, token)
    call s:chatsdb.append_partial(a:chat_id, a:token)
    if a:chat_id == s:current_chat
        call s:ui.append_partial(a:token)
    endif
endfunction
call s:client.set_cb('token_cb', {chat_id, token -> s:_on_token_done(chat_id, token)})

" When the streaming is done and entire message is received, we mark it as
" complete and kick off title generation if it is not computed yet
function! s:_on_stream_done(chat_id)
    call s:chatsdb.partial_done(a:chat_id)
    if !s:chatsdb.has_title(a:chat_id)
        call s:client.send_gen_title(a:chat_id, s:chatsdb.get_first_message(a:chat_id))
    endif
endfunction
call s:client.set_cb('stream_done_cb', {chat_id -> s:_on_stream_done(chat_id)})

" When title call is done, we update title in the db. 
" TODO: also update in UI
call s:client.set_cb('title_done_cb', {chat_id, title -> s:chatsdb.set_title(chat_id, title)})

" If chat is selected in UI, show it
call s:ui.set_cb('chat_select_cb', {chat_id -> s:qq_show_chat(chat_id)})

" If UI wants to show chat selection list, we need to get fresh list
call s:ui.set_cb('chat_list_cb', { -> s:qq_show_chat_list()})

" Sends new message to the server
function! s:qq_send_message(question, use_context)
    let l:context = s:ui.get_visual_selection()
    if a:use_context
        let l:question = s:fmt_question(l:context, a:question)
    else
        let l:question = a:question
    endif
    let l:message  = {"role": "user", "content": l:question}
    let l:chat_id = s:current_chat_id() 
    " timestamp and other metadata might get appended here
    call s:chatsdb.append_message(l:chat_id, l:message)
    call s:chatsdb.clear_partial(l:chat_id)
    call s:qq_show_chat(l:chat_id)
    call s:ui.display_prompt()
    call s:client.send_chat(l:chat_id, s:chatsdb.get_messages(l:chat_id))
endfunction

" sends a warmup message to the server to pre-fill kv cache with context.
function! s:qq_warmup()
    let l:context = s:ui.get_visual_selection()
    if !empty(l:context)
        let l:chat_id = s:current_chat_id()
        let l:content = s:fmt_question(l:context, "")
        let l:message = [{"role": "user", "content": l:content}]
        let l:messages = s:chatsdb.get_messages(l:chat_id) + l:message
        call s:client.send_warmup(l:chat_id, l:messages)
        call feedkeys(":'<,'>QQ ", 'n')
    endif
endfunction

" show/hide qq window. window might contain individual chat or history of past
" conversations. qq_show_chat and qq_show_chat_list functions are used to
" switch between these two views
function! s:qq_toggle_window()
    call s:ui.toggle()
endfunction

" start new chat
function! s:qq_new_chat()
    call s:qq_show_chat(s:chatsdb.new_chat())
endfunction

" show list of chats to select from 
function! s:qq_show_chat_list()
    let l:history = s:chatsdb.get_ordered_chats()
    call s:ui.display_chat_history(l:history, s:current_chat)
endfunction

function! s:qq_show_chat(chat_id)
    let s:current_chat = a:chat_id
    let l:messages     = s:chatsdb.get_messages(a:chat_id)
    let l:partial      = s:chatsdb.get_partial(a:chat_id)

    call s:ui.display_chat(l:messages, l:partial)
endfunction

" -----------------------------------------------------------------------------
"  commands and default key mappings
xnoremap <silent> QQ :<C-u>call <SID>qq_warmup()<CR>

command! -range -nargs=+ QQ  call s:qq_send_message(<q-args>, v:true)
command!        -nargs=+ Q   call s:qq_send_message(<q-args>, v:false)
command!        -nargs=1 QL  call s:qq_show_chat(<f-args>)
command!        -nargs=0 QN  call s:qq_new_chat()
command!        -nargs=0 QP  call s:qq_show_chat_list()
command!        -nargs=0 QT  call s:qq_toggle_window()
