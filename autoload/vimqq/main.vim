if exists('g:autoloaded_vimqq_main')
    finish
endif

let g:autoloaded_vimqq_main = 1

" -----------------------------------------------------------------------------
let s:ui      = vimqq#ui#new()
let s:chatsdb = vimqq#chatsdb#new()
let s:bots    = vimqq#bots#bots#new()
let s:state   = vimqq#state#new(s:chatsdb)
let s:warmup  = vimqq#warmup#new(s:bots, s:chatsdb)
let s:autowarm = vimqq#autowarm#new()

function! s:new() abort
    let l:controller = {}

    function! l:controller.handle_event(event, args) dict
        if a:event == 'chat_selected'
            call vimqq#main#show_chat(a:args['chat_id'])
            return
        endif
        if a:event == 'reply_saved'
            let chat_id = a:args['chat_id']
            let bot = a:args['bot']
            " TODO: modify this with event/observer based 
            if s:chatsdb.chat_len(chat_id) <= 2
                call bot.send_gen_title(chat_id, s:chatsdb.get_first_message(chat_id))
            endif

            " this might call the next query in queue
            if s:state.reply_complete(chat_id)
                " TODO: do we need this? Need to test more to see if it makes sense.
                " We probably do, because if we are in hidden reasoning mode, we won't
                " update UI on partial replies.
                call vimqq#main#show_chat(chat_id)
            endif
            call s:ui.update_queue_size(s:state.queue_size())
            return
        endif
        if a:event == 'delete_chat'
            let chat_id = a:args['chat_id']
            if !s:chatsdb.chat_exists(chat_id)
                call vimqq#log#info("trying to delete non-existent chat")
                return
            endif
            let title = s:chatsdb.get_title(chat_id)
            let choice = confirm("Are you sure you want to delete '" . title . "'?", "&Yes\n&No", 2)
            if choice != 1
                return
            endif

            call s:chatsdb.delete_chat(chat_id)
            if s:state.get_chat_id() == chat_id
                " TODO - select next chat instead
                s:state.set_chat_id(-1)
            endif
            call vimqq#main#show_list()
            return
        endif
    endfunction

    return l:controller
endfunction

let s:controller = s:new()

call vimqq#model#set_state(s:state)
call vimqq#model#add_observer(s:chatsdb)
call vimqq#model#add_observer(s:ui)
call vimqq#model#add_observer(s:warmup)
call vimqq#model#add_observer(s:controller)
call vimqq#model#add_observer(s:autowarm)

" -----------------------------------------------------------------------------
" Setting up wiring between modules

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
endfunction

" Sends new message to the server
function! vimqq#main#send_message(context_mode, force_new_chat, question)
    call s:autowarm.stop()
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
    call s:autowarm.start(l:bot, l:messages)
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

function! vimqq#main#show_current_chat()
    let l:chat_id = s:state.get_chat_id()
    if l:chat_id == -1
        call vimqq#log#error("No current chat to show")
        return
    endif
    call vimqq#main#show_chat(l:chat_id)
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
        call vimqq#log#error('no chat to fork')
        return
    endif

    if s:chatsdb.is_empty(l:src_chat_id)
        call vimqq#log#error('unable to fork empty chat')
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

function! vimqq#main#fzf() abort
    call vimqq#fzf#show(s:chatsdb)
endfunction
