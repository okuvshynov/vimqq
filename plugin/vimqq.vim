" Copyright 2024 Oleksandr Kuvshynov

" -----------------------------------------------------------------------------
" configuration
let g:vqq_llama_servers = get(g:, 'vqq_llama_servers', [])
let g:vqq_claude_models = get(g:, 'vqq_claude_models', [])
let g:vqq_default_bot   = get(g:, 'vqq_default_bot',   '')

let g:vqq_warmup_on_chat_open = get(g:, 'vqq_warmup_on_chat_open', [])
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

call vimqq#ui#new()

let s:ui      = vimqq#ui#new()
let s:chatsdb = vimqq#chatsdb#new()

let s:clients = []

function! s:validate_bot_name(name) abort
    " Check if name is 'You'
    if a:name ==# 'You'
        throw "Bot name 'You' is not allowed"
    endif

    " Check if name contains only allowed characters
    if a:name !~# '^[A-Za-z0-9_]\+$'
        throw "Bot name must contain only letters, numbers, and underscores"
    endif

    " Check if a bot with the same name already exists
    for client in s:clients
        if client.name() ==# a:name
            throw "A bot with the name '" . a:name . "' already exists"
        endif
    endfor
endfunction

for llama_conf in g:vqq_llama_servers
    if !has_key(llama_conf, 'bot_name')
        throw "Each bot must have a 'bot_name' field"
    endif
    call s:validate_bot_name(llama_conf.bot_name)
    call add(s:clients, vimqq#llama#new(llama_conf))
endfor

for claude_conf in g:vqq_claude_models
    if !has_key(claude_conf, 'bot_name')
        throw "Each bot must have a 'bot_name' field"
    endif
    call s:validate_bot_name(claude_conf.bot_name)
    call add(s:clients, vimqq#claude#new(claude_conf))
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

function! s:_pick_client(question)
    for c in s:clients
        let l:tag = '@' . c.name()
        if strpart(a:question, 0, len(l:tag)) ==# l:tag
            " removing tag before passing it to backend
            return [c, strpart(a:question, len(l:tag))]
        endif
    endfor
    return [s:default_client, a:question]
endfunction

function! s:_expand_context(context)
    return vimqq#utils#expand_context(a:context, 3, 2, 10)
endfunction

" -----------------------------------------------------------------------------
" entry points to the plugin

" Sends new message to the server
function! s:qq_send_message(question, use_context, force_new_chat=v:false, expand_context=v:false)
    " pick the bot. we modify message inplace to allow removing bot tag.
    let [l:client, l:question] = s:_pick_client(a:question)

    " in this case bot_name means 'who is asked/tagged'. the author of this message is user. 
    let l:message = {
          \ "role"     : "user",
          \ "message"  : l:question,
          \ "bot_name" : l:client.name()
    \ }

    if a:use_context
        let l:selection = s:ui.get_visual_selection()
        let l:message.selection = l:selection
        if a:expand_context
            let l:message.context =  s:_expand_context(l:selection)
        endif
    endif

    if a:force_new_chat
        let l:chat_id = s:chatsdb.new_chat()
    else
        let l:chat_id = s:current_chat_id() 
    endif
    " timestamp and other metadata might get appended here
    call s:chatsdb.append_message(l:chat_id, l:message)
    call s:chatsdb.reset_partial(l:chat_id, l:client.name())
    call s:qq_show_chat(l:chat_id)
    call l:client.send_chat(l:chat_id, s:chatsdb.get_messages(l:chat_id))
endfunction

" sends a warmup message to the server to pre-fill kv cache with context.
function! s:qq_send_warmup(use_context, force_new_chat, expand_context, tag="")
    let l:message = {
          \ "role"     : "user",
          \ "message"  : "",
    \ }
    if a:use_context
        let l:selection = s:ui.get_visual_selection()
        let l:message.selection = l:selection
        if a:expand_context
            let l:message.context =  s:_expand_context(l:selection)
        endif
    endif

    if a:force_new_chat
        let l:chat_id = s:chatsdb.new_chat()
    else
        let l:chat_id = s:current_chat_id() 
    endif

    let [l:client, _msg] = s:_pick_client(a:tag)
    let l:messages = s:chatsdb.get_messages(l:chat_id) + [l:message]

    call l:client.send_warmup(l:chat_id, l:messages)
endfunction

" show/hide qq window. window might contain individual chat or history of past
" conversations. qq_show_chat and qq_show_chat_list functions are used to
" switch between these two views
function! s:qq_toggle_window()
    call s:ui.toggle()
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
    for bot_name in g:vqq_warmup_on_chat_open
        " no context, no new chat creation
        call s:qq_send_warmup(v:false, v:false, v:false, "@" . bot_name)
    endfor
endfunction

" -----------------------------------------------------------------------------
"  commands. this is the API for the plugin
command!        -nargs=+ VQQSend        call s:qq_send_message(<q-args>, v:false, v:false)
command!        -nargs=+ VQQSendNew     call s:qq_send_message(<q-args>, v:false, v:true)
command! -range -nargs=+ VQQSendCtx     call s:qq_send_message(<q-args>, v:true,  v:false)
command! -range -nargs=+ VQQSendNewCtx  call s:qq_send_message(<q-args>, v:true,  v:true)

" gets bot name as parameter optionally
command!        -nargs=? VQQWarm        call s:qq_send_warmup(v:false, v:false, v:false, <q-args>)
command!        -nargs=? VQQWarmNew     call s:qq_send_warmup(v:false, v:true,  v:false, <q-args>)
command! -range -nargs=? VQQWarmCtx     call s:qq_send_warmup(v:true,  v:false, v:false, <q-args>)
command! -range -nargs=? VQQWarmNewCtx  call s:qq_send_warmup(v:true,  v:true,  v:false, <q-args>)

" extra context using ctags
command! -range -nargs=+ VQQSendCtxEx    call s:qq_send_message(<q-args>, v:true,  v:false, v:true)
command! -range -nargs=+ VQQSendNewCtxEx call s:qq_send_message(<q-args>, v:true,  v:true, v:true)
command! -range -nargs=? VQQWarmCtxEx    call s:qq_send_warmup(v:true, v:false, v:true, <q-args>)
command! -range -nargs=? VQQWarmNewCtxEx call s:qq_send_warmup(v:true, v:true, v:true, <q-args>)

command!        -nargs=0 VQQList        call s:qq_show_chat_list()
command!        -nargs=1 VQQOpenChat    call s:qq_show_chat(<f-args>)
command!        -nargs=0 VQQToggle      call s:qq_toggle_window()

" -----------------------------------------------------------------------------
"  Wrapper helper functions, useful for key mappings definitions
function! VQQWarmupEx(bot)
    execute 'VQQWarmCtxEx ' . a:bot 
    call feedkeys(":'<,'>VQQSendCtxEx " . a:bot . " ", 'n')
endfunction

function! VQQWarmupNewEx(bot)
    execute 'VQQWarmNewCtxEx ' . a:bot 
    call feedkeys(":'<,'>VQQSendNewCtxEx " . a:bot . " ", 'n')
endfunction

function! VQQWarmup(bot)
    execute 'VQQWarmCtx ' . a:bot 
    call feedkeys(":'<,'>VQQSendCtx " . a:bot . " ", 'n')
endfunction

function! VQQWarmupNew(bot)
    execute 'VQQWarmNewCtx ' . a:bot 
    call feedkeys(":'<,'>VQQSendNewCtx " . a:bot . " ", 'n')
endfunction

function! VQQQuery(bot)
    call feedkeys(":VQQSend " . a:bot . " ", 'n')
endfunction

function! VQQQueryNew(bot)
    call feedkeys(":VQQSendNew " . a:bot . " ", 'n')
endfunction

