" Copyright 2024 Oleksandr Kuvshynov

" -----------------------------------------------------------------------------
" configuration
let g:vqq_llama_servers = get(g:, 'vqq_llama_servers', [])
let g:vqq_claude_models = get(g:, 'vqq_claude_models', [])
let g:vqq_default_bot   = get(g:, 'vqq_default_bot',   '')

" -----------------------------------------------------------------------------
" script-level mutable state
" this is the active chat id. New queries would go to this chat by default
let s:current_chat = -1 

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
source anthropic_client.vim

let s:ui      = g:vqq#UI.new()
let s:chatsdb = g:vqq#ChatsDB.new()

let s:clients = []

for llama_conf in g:vqq_llama_servers
    call add(s:clients, g:vqq#LlamaClient.new(llama_conf))
endfor

for claude_conf in g:vqq_claude_models
    call add(s:clients, g:vqq#ClaudeClient.new(claude_conf))
endfor

if empty(s:clients)
    echo "no clients for vim-qq"
    finish
endif

let s:default_client = s:clients[0]
for client in s:clients
    if client.name() ==# g:vqq_default_bot
        let s:default_client = client
    endif
endfor

" -----------------------------------------------------------------------------
" Setting up wiring between modules

function! s:_on_token_done(chat_id, token)
    call s:chatsdb.append_partial(a:chat_id, a:token)
    if a:chat_id == s:current_chat
        call s:ui.append_partial(a:token)
    endif
endfunction

function! s:_on_stream_done(chat_id, client)
    call s:chatsdb.partial_done(a:chat_id)
    if !s:chatsdb.has_title(a:chat_id)
        call a:client.send_gen_title(a:chat_id, s:chatsdb.get_first_message(a:chat_id))
    endif
endfunction

" When server updates health status, we update status line
" When server produces new streamed token, we update db and maybe update ui, 
" if the chat we show is the one updated
" When the streaming is done and entire message is received, we mark it as
" complete and kick off title generation if it is not computed yet
for c in s:clients
    call c.set_cb('title_done_cb', {chat_id, title -> s:chatsdb.set_title(chat_id, title)})
    call c.set_cb('stream_done_cb', {chat_id, client -> s:_on_stream_done(chat_id, client)})
    call c.set_cb('status_cb', {status, client -> s:ui.update_statusline(status, client.name())})
    call c.set_cb('token_cb', {chat_id, token -> s:_on_token_done(chat_id, token)})
endfor

" If chat is selected in UI, show it
call s:ui.set_cb('chat_select_cb', {chat_id -> s:qq_show_chat(chat_id)})

" If UI wants to show chat selection list, we need to get fresh list
call s:ui.set_cb('chat_list_cb', { -> s:qq_show_chat_list()})

" -----------------------------------------------------------------------------
" entry points to the plugin

" Sends new message to the server
function! s:qq_send_message(question, use_context)
    let l:context = s:ui.get_visual_selection()
    " pick the bot
    let l:client = s:default_client
    let l:question = a:question

    for c in s:clients
        let l:tag = '@' . c.name()
        if strpart(a:question, 0, len(l:tag)) ==# l:tag
            let l:client = c
            " removing tag before passing it to backend
            let l:question = strpart(a:question, len(l:tag))
            break
        endif
    endfor

    if a:use_context
        let l:question = s:fmt_question(l:context, l:question)
    endif

    " in this case bot_name means 'who is asked/tagged'
    let l:message  = {"role": "user", "content": l:question, "bot_name": l:client.name()}
    let l:chat_id = s:current_chat_id() 
    " timestamp and other metadata might get appended here
    call s:chatsdb.append_message(l:chat_id, l:message)
    call s:chatsdb.reset_partial(l:chat_id, l:client.name())
    call s:qq_show_chat(l:chat_id)
    call l:client.send_chat(l:chat_id, s:chatsdb.get_messages(l:chat_id))
endfunction

" sends a warmup message to the server to pre-fill kv cache with context.
function! s:qq_warmup()
    let l:context = s:ui.get_visual_selection()
    if !empty(l:context)
        let l:chat_id = s:current_chat_id()
        let l:content = s:fmt_question(l:context, "")
        let l:message = [{"role": "user", "content": l:content}]
        let l:messages = s:chatsdb.get_messages(l:chat_id) + l:message
        call s:default_client.send_warmup(l:chat_id, l:messages)
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
