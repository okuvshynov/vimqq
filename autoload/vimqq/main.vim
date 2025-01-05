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
let s:dispatcher = vimqq#dispatcher#new(s:chatsdb)  

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
            if s:dispatcher.reply_complete(chat_id)
                " TODO: do we need this? Need to test more to see if it makes sense.
                " We probably do, because if we are in hidden reasoning mode, we won't
                " update UI on partial replies.
                call vimqq#main#show_chat(chat_id)
            endif
            call s:ui.update_queue_size(s:dispatcher.queue_size())
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

call vimqq#events#set_state(s:state)
call vimqq#events#add_observer(s:chatsdb)
call vimqq#events#add_observer(s:ui)
call vimqq#events#add_observer(s:warmup)
call vimqq#events#add_observer(s:controller)

" -----------------------------------------------------------------------------
" This is 'internal API' - functions called by defined public commands

" Sends new message to the server
function! vimqq#main#send_message(force_new_chat, question, context=v:null)
    " pick the bot. we modify message and remove bot tag
    let [l:bot, l:question] = s:bots.select(a:question)

    " In this case bot_name means 'who is asked/tagged'.
    " The author of this message is user. TODO: Rename to 'tagged_bot'
    let l:message = {
          \ "role"     : 'user',
          \ "message"  : l:question,
          \ "bot_name" : l:bot.name()
    \ }

    let l:message = vimqq#fmt#fill_context(l:message, a:context)

    let l:chat_id = s:state.pick_chat_id(a:force_new_chat)
    call vimqq#metrics#user_started_waiting(l:chat_id)
    call vimqq#log#debug('user started waiting')
    if s:dispatcher.enqueue_query(l:chat_id, l:bot, l:message)
        call vimqq#main#show_chat(l:chat_id)
    endif

    call s:ui.update_queue_size(s:dispatcher.queue_size())
endfunction

" sends a warmup message to the server to pre-fill kv cache with context.
function! vimqq#main#send_warmup(force_new_chat, question, context=v:null)
    let [l:bot, l:question] = s:bots.select(a:question)
    let l:message = {
          \ "role"     : 'user',
          \ "message"  : l:question,
          \ "bot_name" : l:bot.name()
    \ }

    let l:message = vimqq#fmt#fill_context(l:message, a:context)

    let l:chat_id = s:state.get_chat_id()

    if l:chat_id >= 0 && !a:force_new_chat
        let l:messages = s:chatsdb.get_messages(l:chat_id) + [l:message]
    else
        let l:messages = [l:message]
    endif

    call vimqq#log#debug('Sending warmup with message of ' . len(l:messages))
    call l:bot.send_warmup(l:messages)
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

" -----------------------------------------------------------------------------
function! vimqq#main#qq(message) abort range
    call vimqq#log#debug('qq: sending message')
    let l:lines = getline(a:firstline, a:lastline)
    let l:context = join(l:lines, '\n')
    call vimqq#main#send_message(v:false, a:message, l:context)
endfunction

function! vimqq#main#qqn(message) abort range
    call vimqq#log#debug('qq: sending message')
    let l:lines = getline(a:firstline, a:lastline)
    let l:context = join(l:lines, '\n')
    call vimqq#main#send_message(v:true, a:message, l:context)
endfunction

function! vimqq#main#q(message) abort
    call vimqq#log#debug('q: sending message')
    call vimqq#main#send_message(v:false, a:message)
endfunction

function! vimqq#main#qn(message) abort
    call vimqq#log#debug('qn: sending message')
    call vimqq#main#send_message(v:true, a:message)
endfunction

function! vimqq#main#dispatch_new(count, line1, line2, args) abort
    call vimqq#log#info('dispatching')
    if a:count == -1
        " No range was provided
        call vimqq#main#qn(a:args)
    else
        " Range was provided, pass the line numbers
        execute a:line1 . ',' . a:line2 . 'call vimqq#main#qqn(a:args)'
    endif
endfunction

function! vimqq#main#dispatch(count, line1, line2, args) abort
    call vimqq#log#info('dispatching')
    if a:count == -1
        " No range was provided
        call vimqq#main#q(a:args)
    else
        " Range was provided, pass the line numbers
        execute a:line1 . ',' . a:line2 . 'call vimqq#main#qq(a:args)'
    endif
endfunction

" TODO: forking will become particularly important if we use lucas index
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

    if s:dispatcher.enqueue_query(l:chat_id, l:bot, l:message)
        call vimqq#main#show_chat(l:chat_id)
    endif
    call s:ui.update_queue_size(s:state.queue_size())
endfunction

function! vimqq#main#fzf() abort
    call vimqq#fzf#show(s:chatsdb)
endfunction

function! vimqq#main#init() abort
    " Just to autoload
endfunction
