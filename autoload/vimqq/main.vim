if exists('g:autoloaded_vimqq_main')
    finish
endif

let g:autoloaded_vimqq_main = 1

" -----------------------------------------------------------------------------
function! s:new() abort
    let controller = {}

    function! controller.handle_event(event, args) dict
        if a:event ==# 'chat_selected'
            call vimqq#main#show_chat(a:args['chat_id'])
            return
        endif
        " This is when the reply from bot is fully processed and recorded
        " Now we need to react to it - maybe generate title and check if
        " There are any tool calls.
        if a:event ==# 'reply_saved'
            let chat_id = a:args['chat_id']
            let bot = a:args['bot']
            
            call vimqq#main#show_chat(chat_id)
            
            let messages = s:chatsdb.get_messages(chat_id)
            if len(messages) > 0 
                let last_message = messages[len(messages) - 1]
                if has_key(last_message, 'tool_use') 
                    " TODO: this is sync operation
                    let tool_result = s:toolset.run(last_message.tool_use)
                    let tool_reply = {
                    \   "role": "user", 
                    \   "content" : [{
                    \       "type": "tool_result",
                    \       "tool_use_id": last_message.tool_use['id'],
                    \       "content": tool_result
                    \   }],
                    \   "bot_name": bot.name()
                    \ }

                    if s:dispatcher.enqueue_query(chat_id, bot, tool_reply)
                        call vimqq#main#show_chat(chat_id)
                    endif

                    call s:ui.update_queue_size(s:dispatcher.queue_size())
                endif
            endif
    
            " TODO: modify this with event/observer based 
            if s:chatsdb.chat_len(chat_id) <= 2
                call bot.send_gen_title(chat_id, s:chatsdb.get_first_message(chat_id))
            endif

            " this might call the next query in queue
            if s:dispatcher.reply_complete(chat_id)
                call vimqq#main#show_chat(chat_id)
            endif
            call s:ui.update_queue_size(s:dispatcher.queue_size())
            return
        endif
        if a:event ==# 'delete_chat'
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
            if s:state.get_chat_id() ==# chat_id
                " TODO - select next chat instead
                call s:state.set_chat_id(-1)
            endif

            " TODO: do we need this?
            call vimqq#main#show_list()
            return
        endif
    endfunction

    return controller
endfunction

function! vimqq#main#setup()
    let s:ui      = vimqq#ui#new()
    let s:chatsdb = vimqq#chatsdb#new()
    let s:bots    = vimqq#bots#bots#new()
    let s:state   = vimqq#state#new(s:chatsdb)
    let s:warmup  = vimqq#warmup#new(s:bots, s:chatsdb)
    let s:dispatcher = vimqq#dispatcher#new(s:chatsdb)  
    let s:toolset = vimqq#tools#toolset#new()

    let s:controller = s:new()

    call vimqq#events#set_state(s:state)
    call vimqq#events#clear_observers()
    call vimqq#events#add_observer(s:chatsdb)
    call vimqq#events#add_observer(s:ui)
    call vimqq#events#add_observer(s:warmup)
    call vimqq#events#add_observer(s:controller)
endfunction

call vimqq#main#setup()

" -----------------------------------------------------------------------------
" This is 'internal API' - functions called by defined public commands

" Sends new message to the server
function! vimqq#main#send_message(force_new_chat, question, context=v:null, use_index=v:false)
    " pick the bot. we modify message and remove bot tag
    let [bot, question] = s:bots.select(a:question)

    " In this case bot_name means 'who is asked/tagged'.
    " The author of this message is user. TODO: Rename to 'tagged_bot'
    let message = {
          \ "role"     : 'user',
          \ "sources"  : { "text": question },
          \ "bot_name" : bot.name()
    \ }

    let message = vimqq#fmt#fill_context(message, a:context, a:use_index)

    let chat_id = s:state.pick_chat_id(a:force_new_chat)

    " TODO: when do we allow tools? Currently, if index is allowed.
    if a:use_index
        " TODO: Assumes everything is anthropic
        call s:chatsdb.set_tools(chat_id, s:toolset.def(v:true))
    endif
    if s:dispatcher.enqueue_query(chat_id, bot, message)
        call vimqq#main#show_chat(chat_id)
    endif

    call s:ui.update_queue_size(s:dispatcher.queue_size())
endfunction

" sends a warmup message to the server to pre-fill kv cache with context.
function! vimqq#main#send_warmup(force_new_chat, question, context=v:null)
    let [bot, question] = s:bots.select(a:question)
    let message = {
          \ "role"     : 'user',
          \ "sources"  : { "text": question },
          \ "bot_name" : bot.name()
    \ }

    let message = vimqq#fmt#fill_context(message, a:context, v:false)

    let chat_id = s:state.get_chat_id()

    if chat_id >= 0 && !a:force_new_chat
        let messages = s:chatsdb.get_messages(chat_id) + [message]
    else
        let messages = [message]
    endif

    call vimqq#log#debug('Sending warmup with message of ' . len(messages))
    call bot.send_warmup(messages)
endfunction

" show chat history
function! vimqq#main#show_list()
    let history = s:chatsdb.get_ordered_chats()
    call s:ui.display_chat_history(history, s:state.get_chat_id())
endfunction

function! vimqq#main#show_chat(chat_id)
    if !s:chatsdb.chat_exists(a:chat_id)
        call vimqq#log#error("Attempting to show non-existent chat")
        return
    endif
    call s:state.set_chat_id(a:chat_id)
    let messages = s:chatsdb.get_messages(a:chat_id)
    let partial  = s:chatsdb.get_partial(a:chat_id)
    call s:ui.display_chat(messages, partial)
endfunction

" TODO: forking will become particularly important if we use lucas index
function! vimqq#main#fork_chat(args) abort
    let args = split(a:args, ' ')
    let src_chat_id = s:state.get_chat_id()
    if src_chat_id ==# -1
        call vimqq#log#error('no chat to fork')
        return
    endif

    if s:chatsdb.is_empty(src_chat_id)
        call vimqq#log#error('unable to fork empty chat')
        return
    endif

    let message = deepcopy(s:chatsdb.get_first_message(src_chat_id))
    " TODO: this is likely wrong
    let message.message = join(args, ' ')

    let [bot, _msg] = s:bots.select('@' . message.bot_name)

    let chat_id = s:chatsdb.new_chat()

    if s:dispatcher.enqueue_query(chat_id, bot, message)
        call vimqq#main#show_chat(chat_id)
    endif
    call s:ui.update_queue_size(s:dispatcher.queue_size())
endfunction

function! vimqq#main#init() abort
    " Just to autoload
endfunction

function! vimqq#main#fzf() abort
    call vimqq#fzf#show(s:chatsdb)
endfunction

