if exists('g:autoloaded_vimqq_main')
    finish
endif

let g:autoloaded_vimqq_main = 1

" -----------------------------------------------------------------------------
let g:vqq_warmup_on_chat_open = get(g:, 'vqq_warmup_on_chat_open', [])
" -----------------------------------------------------------------------------
let s:ui      = vimqq#ui#new()
let s:chatsdb = vimqq#chatsdb#new()
let s:bots    = vimqq#bots#bots#new()
let s:state   = vimqq#state#new(s:chatsdb)

" TODO: make this a property of a bot, not a separate list
let s:warmup_bots = []
for bot in s:bots.bots()
    if index(g:vqq_warmup_on_chat_open, bot.name()) != -1
        call add(s:warmup_bots, bot)
    endif
endfor

" -----------------------------------------------------------------------------
" Setting up wiring between modules

function! s:_send_warmup(chat_id)
    if !s:chatsdb.chat_exists(a:chat_id)
        call vimqq#log#info("warmup on non-existent chat.")
        return
    endif
    for bot in s:warmup_bots
        let messages = s:chatsdb.get_messages(a:chat_id)
        call vimqq#metrics#inc(bot.name() . ".chat_warmups" )
        call bot.send_warmup(messages)
    endfor
endfunction

" invoke a callback function for a chat, handling the case where the chat
" may have been deleted before the callback is processed. If the chat no longer
" exists, log a message and skip executing the callback.
function! s:_if_exists(Fn, chat_id, ...)
    if !s:chatsdb.chat_exists(a:chat_id)
        call vimqq#log#info("callback on non-existent chat.")
        return
    endif
    call call(a:Fn, [a:chat_id] + a:000)
endfunction

" append the received token to message in database, and optionally to UI,
" if the chat is currently open
function! s:_on_token_done(chat_id, token)
    call vimqq#metrics#inc('n_deltas')
    if empty(s:chatsdb.get_partial(a:chat_id).content)
        " to track TTFT latency
        call s:state.first_token(a:chat_id)
    endif
    call s:chatsdb.append_partial(a:chat_id, a:token)
    if a:chat_id == s:state.get_chat_id()
        call s:ui.append_partial(a:token)
    endif
endfunction

" when we received complete message, we generate title, mark query as complete
function! s:_on_reply_complete(chat_id, bot)
    call vimqq#log#debug('n_deltas = ' . vimqq#metrics#get('n_deltas'))
    call s:chatsdb.partial_done(a:chat_id)
    if !s:chatsdb.has_title(a:chat_id)
        call a:bot.send_gen_title(a:chat_id, s:chatsdb.get_first_message(a:chat_id))
    endif

    " this might call the next query in queue
    if s:state.reply_complete(a:chat_id)
        " TODO: do we need this? Need to test more to see if it makes sense.
        " We probably do, because if we are in hidden reasoning mode, we won't
        " update UI on partial replies.
        call vimqq#main#show_chat(a:chat_id)
    endif
    call s:ui.update_queue_size(s:state.queue_size())
endfunction

function! s:_on_title_done(chat_id, title)
    call s:chatsdb.set_title(a:chat_id, a:title)
    call s:_send_warmup(a:chat_id)
endfunction

function! s:_on_chat_select(chat_id)
    call vimqq#main#show_chat(a:chat_id)
    call s:_send_warmup(a:chat_id)
endfunction

for bot in s:bots.bots()
    " When title is ready, we set it in db
    call bot.set_cb(
          \ 'title_done_cb', 
          \ {chat_id, title -> s:_if_exists(function('s:_on_title_done'), chat_id, title)}
    \ )
    " When the streaming is done and entire message is received, we mark it as
    " complete and kick off title generation if it is not computed yet
    call bot.set_cb(
          \ 'stream_done_cb', 
          \ {chat_id, bot -> s:_if_exists(function('s:_on_reply_complete'), chat_id, bot)}
    \ )
    " When server produces new streamed token, we update db and maybe update ui, 
    call bot.set_cb(
          \ 'token_cb',
          \ {chat_id, token -> s:_if_exists(function('s:_on_token_done'), chat_id, token)}
    \ )
    " When server updates health status, we update status line
    call bot.set_cb(
          \ 'status_cb',
          \ {status, bot -> s:ui.update_statusline(status, bot.name())}
    \ )
    " When warmup is done we check if we have updated message and send new warmup
    call bot.set_cb('warmup_done_cb', { -> vimqq#autowarm#next()})
endfor

" If chat is selected in UI, show it
call s:ui.set_cb(
      \ 'chat_select_cb', 
      \ {chat_id -> s:_if_exists(function('s:_on_chat_select'), chat_id)}
\ )
" If chat was requested for deletion, show confirmation, delete it and update UI
call s:ui.set_cb(
      \ 'chat_delete_cb',
      \ {chat_id -> s:_if_exists(function('vimqq#main#delete_chat'), chat_id)}
\ )
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
        " TODO - select next chat instead
        s:state.set_chat_id(-1)
    endif
    call vimqq#main#show_list()
endfunction

" Sends new message to the server
function! vimqq#main#send_message(context_mode, force_new_chat, question)
    call vimqq#autowarm#stop()
    " pick the bot. we modify message and remove bot tag
    let [l:bot, l:question] = s:bots.select(a:question)

    " In this case bot_name means 'who is asked/tagged'.
    " The author of this message is user. TODO: Rename to 'tagged_bot'
    let l:message = {
          \ "role"     : 'user',
          \ "message"  : l:question,
          \ "bot_name" : l:bot.name()
    \ }

    let l:message = vimqq#context#context#fill(l:message, a:context_mode)

    let l:chat_id = s:state.pick_chat_id(a:force_new_chat)
    call s:state.user_started_waiting(l:chat_id)
    call vimqq#log#debug('user started waiting')
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
    let l:message = vimqq#context#context#fill(l:message, a:context_mode)

    let l:chat_id = s:state.get_chat_id()
    let [l:bot, _msg] = s:bots.select(a:tag)
    if l:chat_id >= 0 && !a:force_new_chat
        let l:messages = s:chatsdb.get_messages(l:chat_id) + [l:message]
    else
        let l:messages = [l:message]
    endif

    call vimqq#log#debug('Sending warmup with message of ' . len(l:messages))
    call l:bot.send_warmup(l:messages)
    call vimqq#autowarm#start(l:bot, l:messages)
endfunction

" show list of chats to select from 
function! vimqq#main#show_list()
    let l:history = s:chatsdb.get_ordered_chats()
    call s:ui.display_chat_history(l:history, s:state.get_chat_id())
endfunction

function! vimqq#main#show_chat(chat_id)
    if !s:chatsdb.chat_exists(a:chat_id)
        call vimqq#log#error("Attempting to show non-existent chat")
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

function! s:_execute(args, ctx_keys)
    let args = split(a:args, ' ')
    let params = []
    let name = ''
    let message = ''

    " Parse optional params starting with '-'
    " For example, -nfw would mean 
    "  - send in [n]ew chat 
    "  - include current [f]ile as context
    "  - send a [w]armup query
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

    for [k, v] in items(a:ctx_keys)
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

" -----------------------------------------------------------------------------
function! vimqq#main#qq(args) abort
    call vimqq#log#debug('qq: sending message')
    let l:ctx_keys = {
        \ 's' : 'selection',
        \ 'f' : 'file',
        \ 'p' : 'project',
        \ 't' : 'ctags',
        \ 'b' : 'blame'
    \}

    call s:_execute(a:args, l:ctx_keys)
endfunction

function! vimqq#main#q(args) abort
    call vimqq#log#debug('q: sending message')
    let l:ctx_keys = {
        \ 'f' : 'file',
        \ 'p' : 'project',
        \ 't' : 'ctags'
    \}

    call s:_execute(a:args, l:ctx_keys)
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

function! vimqq#main#record_eval(evaluation)
    let key = "eval." . s:state.last_bot_name() . "." . a:evaluation
    call vimqq#metrics#inc(key)
endfunction
