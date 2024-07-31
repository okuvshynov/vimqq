if exists('g:autoloaded_vimqq_main')
    finish
endif

let g:autoloaded_vqq_main = 1

" -----------------------------------------------------------------------------
let g:vqq_warmup_on_chat_open = get(g:, 'vqq_warmup_on_chat_open', [])
" -----------------------------------------------------------------------------
let s:ui      = vimqq#ui#new()
let s:chatsdb = vimqq#chatsdb#new()
let s:bots    = vimqq#bots#new()

let s:state   = vimqq#state#new(s:chatsdb)

" -----------------------------------------------------------------------------
" Setting up wiring between modules

" It is possible that chat will get deleted, and after that some callback
" would arrive. Log and skip any further processing. 
function! s:_if_exists(Fn, chat_id, ...)
    if !s:chatsdb.chat_exists(a:chat_id)
        call vimqq#log#info("callback on non-existent chat.")
        return
    endif
    call call(a:Fn, [a:chat_id] + a:000)
endfunction

function! s:_on_token_done(chat_id, token)
    call s:chatsdb.append_partial(a:chat_id, a:token)
    if a:chat_id == s:state.get_chat_id()
        call s:ui.append_partial(a:token)
    endif
endfunction

function! s:_on_reply_complete(chat_id, bot)
    call s:chatsdb.partial_done(a:chat_id)
    if !s:chatsdb.has_title(a:chat_id)
        call a:bot.send_gen_title(a:chat_id, s:chatsdb.get_first_message(a:chat_id))
    endif

    if s:state.reply_complete(a:chat_id)
        call vimqq#main#show_chat(a:chat_id)
    endif
    call s:ui.update_queue_size(s:state.queue_size())
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
    if s:state.get_chat_id() == a:chat_id
        s:state.set_chat_id(-1)
    endif
    call vimqq#main#show_list()
endfunction

" Sends new message to the server
function! vimqq#main#send_message(context_mode, force_new_chat, question)
    " pick the bot. we modify message to allow removing bot tag.
    let [l:bot, l:question] = s:bots.select(a:question)

    " In this case bot_name means 'who is asked/tagged'.
    " Uhe author of this message is user. Rename to 'tagged_bot'
    let l:message = {
          \ "role"     : 'user',
          \ "message"  : l:question,
          \ "bot_name" : l:bot.name()
    \ }

    let l:message = vimqq#context#fill(l:message, a:context_mode)

    let l:chat_id = s:state.pick_chat_id(a:force_new_chat)
    if s:state.enqueue_query(l:chat_id, l:bot, l:message)
        call vimqq#main#show_chat(l:chat_id)
    endif

    call s:ui.update_queue_size(s:state.queue_size())
endfunction

" sends a warmup message to the server to pre-fill kv cache with context.
function! vimqq#main#send_warmup(context_mode, force_new_chat, tag="")
    let l:message = {
          \ "role"     : "user",
          \ "message"  : "",
    \ }
    let l:message = vimqq#context#fill(l:message, a:context_mode)

    let l:chat_id = s:state.pick_chat_id(a:force_new_chat)

    let [l:bot, _msg] = s:bots.select(a:tag)
    let l:messages = s:chatsdb.get_messages(l:chat_id) + [l:message]

    call l:bot.send_warmup(l:chat_id, l:messages)
endfunction

" show list of chats to select from 
function! vimqq#main#show_list()
    let l:history = s:chatsdb.get_ordered_chats()
    call s:ui.display_chat_history(l:history, s:state.get_chat_id())
endfunction

function! vimqq#main#show_chat(chat_id)
    if !s:chatsdb.chat_exists(a:chat_id)
        call vimqq#log#info("Attempting to show non-existent chat")
        return
    endif
    call s:state.set_chat_id(a:chat_id)
    let l:messages = s:chatsdb.get_messages(a:chat_id)
    let l:partial  = s:chatsdb.get_partial(a:chat_id)
    call s:ui.display_chat(l:messages, l:partial)
endfunction

function! vimqq#main#toggle()
    call s:ui.toggle()
endfunction

" main commands
function! vimqq#main#qq(args) abort
    let l:ctx_keys = {
        \ 's' : 'selection',
        \ 'f' : 'file',
        \ 'p' : 'project',
        \ 't' : 'ctags'
    \}

    let args = split(a:args, ' ')
    let params = []
    let name = ''
    let message = ''

    " Parse optional params starting with '-'
    " For example, -nfw would mean 
    "  - send in [n]ew chat 
    "  - include current [f]ile as context
    "  - send a [w]armup query
    "  
    "  Supported options:
    "  - n - [n]ew chat
    "  - w - do [w]armup
    "  - s - use visual [s]election as context
    "  - f - use current [f]ile as context
    "  - p - use entire [p]roject as context --- be careful here
    "  - t - use c[t]ags from the selection as context
    if len(args) > 0
        let param_match = matchlist(args[0], '^-\(.\+\)')
        if !empty(param_match)
            let params = split(param_match[1], '\zs')
            let args = args[1:]
        endif
    endif

    let l:message = join(args, ' ')

    let l:new_chat  = index(params, 'n') >= 0
    let l:do_warmup = index(params, 'w') >= 0

    let l:ctx_options = {}

    for [k, v] in items(l:ctx_keys)
        if index(params, k) >= 0
            let l:ctx_options[v] = 1
        endif
    endfor

    if l:do_warmup
        call vimqq#main#send_warmup(l:ctx_options, l:new_chat, l:message)
    else
        call vimqq#main#send_message(l:ctx_options, l:new_chat, l:message)
    endif
endfunction

function! vimqq#main#q(args) abort
    let l:ctx_keys = {
        \ 'f' : 'file',
        \ 'p' : 'project',
    \}
    let args = split(a:args, ' ')
    let params = []
    let name = ''
    let message = ''

    " Parse optional params starting with '-'
    " For example, -nfw would mean 
    "  - send in [n]ew chat 
    "  - include current [f]ile as context
    "  - send a [w]armup query
    "  
    "  Supported options:
    "  - n - [n]ew chat
    "  - w - do [w]armup
    "  - f - use current [f]ile as context
    "  - p - use entire [p]roject as context --- be careful here
    if len(args) > 0
        let param_match = matchlist(args[0], '^-\(.\+\)')
        if !empty(param_match)
            let params = split(param_match[1], '\zs')
            let args = args[1:]
        endif
    endif

    let l:message = join(args, ' ')

    let l:new_chat  = index(params, 'n') >= 0
    let l:do_warmup = index(params, 'w') >= 0

    let l:ctx_options = {}

    for [k, v] in items(l:ctx_keys)
        if index(params, k) >= 0
            let l:ctx_options[v] = 1
        endif
    endfor

    if l:do_warmup
        call vimqq#main#send_warmup(l:ctx_options, l:new_chat, l:message)
    else
        call vimqq#main#send_message(l:ctx_options, l:new_chat, l:message)
    endif
endfunction

function! vimqq#main#fork_chat(args) abort
    let args = split(a:args, ' ')
    let l:src_chat_id = s:state.get_chat_id()
    if l:src_chat_id == -1
        vimqq#log#error('no chat to fork')
        return
    endif

    if s:chatsdb.is_empty(l:src_chat_id)
        vimqq#log#error('unable to fork empty chat')
        return
    endif

    let l:message = deepcopy(s:chatsdb.get_first_message(l:src_chat_id))
    let l:message.message = join(args, ' ')

    let [l:bot, _msg] = s:bots.select('@' . l:message.bot_name)

    let l:chat_id = s:chatsdb.new_chat()

    if s:state.enqueue_query(l:chat_id, l:bot, l:message)
        call vimqq#main#show_chat(l:chat_id)
    endif
    call s:ui.update_queue_size(s:state.queue_size())
endfunction
