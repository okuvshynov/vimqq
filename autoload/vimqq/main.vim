if exists('g:autoloaded_vimqq_main')
    finish
endif

let g:autoloaded_vqq_main = 1

" -----------------------------------------------------------------------------
let g:vqq_warmup_on_chat_open = get(g:, 'vqq_warmup_on_chat_open', [])
" -----------------------------------------------------------------------------
" script-level mutable state
" this is the active chat id. New queries would go to this chat by default
let s:current_chat = -1 

" We need to handle the following here
"  - if chat is 'awaiting response'
function! s:current_chat_id()
    if s:current_chat == -1
        let s:current_chat = s:chatsdb.new_chat()
    endif
    return s:current_chat
endfunction

let s:ui      = vimqq#ui#new()
let s:chatsdb = vimqq#chatsdb#new()
let s:bots    = vimqq#bots#new()

" -----------------------------------------------------------------------------
" Setting up wiring between modules

" It is possible that chat will get deleted, and after that some callback
" would arrive. Log and skip any further processing
function! s:_if_exists(Fn, chat_id, ...)
    if !s:chatsdb.chat_exists(a:chat_id)
        call vimqq#log#info("callback on non-existent chat.")
        return
    endif
    call call(a:Fn, [a:chat_id] + a:000)
endfunction

function! s:_on_token_done(chat_id, token)
    call s:chatsdb.append_partial(a:chat_id, a:token)
    if a:chat_id == s:current_chat
        call s:ui.append_partial(a:token)
    endif
endfunction

" we need a callback to decide when chat processing is done, if it is
" success/error. We'll need to use it to prevent multiple queries being
" sent for the same chat_id. 
" For example, we have a queue for each chat. When we attempt to send a new
" message to chat, we first check if queue is empty. If it is, we send a 
" message + add the job to the queue in 'processing' state. Once done, we
" remove it and check if more were added to the queue, and process them if
" needed.

function! s:_on_reply_complete(chat_id, bot)
    call s:chatsdb.partial_done(a:chat_id)
    if !s:chatsdb.has_title(a:chat_id)
        call a:bot.send_gen_title(a:chat_id, s:chatsdb.get_first_message(a:chat_id))
    endif
endfunction

" When server updates health status, we update status line
" When server produces new streamed token, we update db and maybe update ui, 
" if the chat we show is the one updated
" When the streaming is done and entire message is received, we mark it as
" complete and kick off title generation if it is not computed yet
for bot in s:bots.bots()
    call bot.set_cb('title_done_cb', {chat_id, title -> s:_if_exists(s:chatsdb.set_title, chat_id, title)})
    call bot.set_cb('stream_done_cb', {chat_id, bot -> s:_if_exists(function('s:_on_reply_complete'), chat_id, bot)})
    call bot.set_cb('token_cb', {chat_id, token -> s:_if_exists(function('s:_on_token_done'), chat_id, token)})
    call bot.set_cb('status_cb', {status, bot -> s:ui.update_statusline(status, bot.name())})
endfor

" If chat is selected in UI, show it
call s:ui.set_cb('chat_select_cb', {chat_id -> s:_if_exists(function('vimqq#main#show_chat'), chat_id)})
" If chat was requested for deletion, delete it and update UI
call s:ui.set_cb('chat_delete_cb', {chat_id -> s:_if_exists(function('vimqq#main#delete_chat'), chat_id)})
" If UI wants to show chat selection list, we need to get fresh list
call s:ui.set_cb('chat_list_cb', { -> vimqq#main#show_list()})

function! s:_fill_context(message, context_mode)
    let l:message = deepcopy(a:message)
    if a:context_mode != "ctx_none"
        let l:selection = s:ui.get_visual_selection()
        let l:message.selection = l:selection
        if a:context_mode == "ctx_ctags"
            let l:message.context = vimqq#context#ctags(l:selection)
        endif
        if a:context_mode == "ctx_full"
            " TODO: get limited file types?
            let l:message.context = vimqq#full_context#get()
        endif
        if a:context_mode == "ctx_file"
            let l:message.context = vimqq#context#file()
        endif
    endif
    return l:message
endfunction

" -----------------------------------------------------------------------------
" This is 'internal API' - functions called by defined public commands

" Deletes the chat. Shows a confirmation dialog to user first
function! vimqq#main#delete_chat(chat_id)
    let title = s:chatsdb.get_title(a:chat_id)
    let choice = confirm("Are you sure you want to delete '" . title . "'?", "&Yes\n&No", 2)
    if choice != 1
        return
    endif

    call s:chatsdb.delete_chat(a:chat_id)
    if s:current_chat == a:chat_id
        let s:current_chat = -1
    endif
    call vimqq#main#show_list()
endfunction

" context_mode is 'ctx_none', 'ctx_range', 'ctx_ctags', 'ctx_full'
" Sends new message to the server
function! vimqq#main#send_message(context_mode, force_new_chat, question)
    " pick the bot. we modify message to allow removing bot tag.
    let [l:bot, l:question] = s:bots.select(a:question)

    " in this case bot_name means 'who is asked/tagged'. the author of this message is user. 
    let l:message = {
          \ "role"     : 'user',
          \ "message"  : l:question,
          \ "bot_name" : l:bot.name()
    \ }

    let l:message = s:_fill_context(l:message, a:context_mode)

    if a:force_new_chat
        let l:chat_id = s:chatsdb.new_chat()
    else
        let l:chat_id = s:current_chat_id() 
    endif
    " timestamp and other metadata might get appended here
    call s:chatsdb.append_message(l:chat_id, l:message)
    call s:chatsdb.reset_partial(l:chat_id, l:bot.name())
    call vimqq#main#show_chat(l:chat_id)
    call l:bot.send_chat(l:chat_id, s:chatsdb.get_messages(l:chat_id))
endfunction

" sends a warmup message to the server to pre-fill kv cache with context.
function! vimqq#main#send_warmup(context_mode, force_new_chat, tag="")
    let l:message = {
          \ "role"     : "user",
          \ "message"  : "",
    \ }
    let l:message = s:_fill_context(l:message, a:context_mode)

    if a:force_new_chat
        let l:chat_id = s:chatsdb.new_chat()
    else
        let l:chat_id = s:current_chat_id() 
    endif

    let [l:bot, _msg] = s:bots.select(a:tag)
    let l:messages = s:chatsdb.get_messages(l:chat_id) + [l:message]

    call l:bot.send_warmup(l:chat_id, l:messages)
endfunction

" show list of chats to select from 
function! vimqq#main#show_list()
    let l:history = s:chatsdb.get_ordered_chats()
    call s:ui.display_chat_history(l:history, s:current_chat)
endfunction

function! vimqq#main#show_chat(chat_id)
    if !s:chatsdb.chat_exists(a:chat_id)
        call vimqq#log#info("Attempting to show non-existent chat")
        return
    endif
    let s:current_chat = a:chat_id
    let l:messages     = s:chatsdb.get_messages(a:chat_id)
    let l:partial      = s:chatsdb.get_partial(a:chat_id)
    call s:ui.display_chat(l:messages, l:partial)
    for bot_name in g:vqq_warmup_on_chat_open
        " no context, no new chat creation
        call vimqq#main#send_warmup("ctx_none", v:false, "@" . bot_name)
    endfor
endfunction

function! vimqq#main#toggle()
    call s:ui.toggle()
endfunction