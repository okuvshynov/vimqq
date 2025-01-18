if exists('g:autoloaded_vimqq_main')
    finish
endif

let g:autoloaded_vimqq_main = 1

" -----------------------------------------------------------------------------
function! s:new() abort
    let controller = {}

    " Move all script-level variables into controller
    let controller.ui = v:null
    let controller.chatsdb = v:null
    let controller.bots = v:null
    let controller.state = v:null
    let controller.warmup = v:null
    let controller.dispatcher = v:null
    let controller.toolset = v:null

    function! controller.init() dict
        let self.ui = vimqq#ui#new()
        let self.chatsdb = vimqq#chatsdb#new()
        let self.bots = vimqq#bots#bots#new()
        let self.state = vimqq#state#new(self.chatsdb)
        let self.warmup = vimqq#warmup#new(self.bots, self.chatsdb)
        let self.dispatcher = vimqq#dispatcher#new(self.chatsdb)  
        let self.toolset = vimqq#tools#toolset#new()

        call vimqq#events#set_state(self.state)
        call vimqq#events#clear_observers()
        call vimqq#events#add_observer(self.chatsdb)
        call vimqq#events#add_observer(self.ui)
        call vimqq#events#add_observer(self.warmup)
        call vimqq#events#add_observer(self)
    endfunction

    function! controller.handle_event(event, args) dict
        if a:event ==# 'chat_selected'
            call self.show_chat(a:args['chat_id'])
            return
        endif

        if a:event ==# 'reply_saved'
            let chat_id = a:args['chat_id']
            let bot = a:args['bot']
            
            call self.show_chat(chat_id)
            
            let messages = self.chatsdb.get_messages(chat_id)
            if len(messages) > 0 
                let last_message = messages[len(messages) - 1]
                if has_key(last_message, 'tool_use') 
                    let tool_result = self.toolset.run(last_message.tool_use)
                    let tool_reply = {
                    \   "role": "user", 
                    \   "content" : [{
                    \       "type": "tool_result",
                    \       "tool_use_id": last_message.tool_use['id'],
                    \       "content": tool_result
                    \   }],
                    \   "bot_name": bot.name()
                    \ }

                    if self.dispatcher.enqueue_query(chat_id, bot, tool_reply)
                        call self.show_chat(chat_id)
                    endif

                    call self.ui.update_queue_size(self.dispatcher.queue_size())
                endif
            endif
    
            if self.chatsdb.chat_len(chat_id) <= 2
                call bot.send_gen_title(chat_id, self.chatsdb.get_first_message(chat_id))
            endif

            if self.dispatcher.reply_complete(chat_id)
                call self.show_chat(chat_id)
            endif
            call self.ui.update_queue_size(self.dispatcher.queue_size())
            return
        endif

        if a:event ==# 'delete_chat'
            let chat_id = a:args['chat_id']
            if !self.chatsdb.chat_exists(chat_id)
                call vimqq#log#info("trying to delete non-existent chat")
                return
            endif
            let title = self.chatsdb.get_title(chat_id)
            let choice = confirm("Are you sure you want to delete '" . title . "'?", "&Yes\n&No", 2)
            if choice != 1
                return
            endif

            call self.chatsdb.delete_chat(chat_id)
            if self.state.get_chat_id() ==# chat_id
                call self.state.set_chat_id(-1)
            endif

            call self.show_list()
            return
        endif
    endfunction

    function! controller.send_message(force_new_chat, question, context, use_index) dict
        let [bot, question] = self.bots.select(a:question)

        let message = {
              \ "role"     : 'user',
              \ "sources"  : { "text": question },
              \ "bot_name" : bot.name()
        \ }

        let message = vimqq#fmt#fill_context(message, a:context, a:use_index)

        let chat_id = self.state.pick_chat_id(a:force_new_chat)

        if a:use_index
            call self.chatsdb.set_tools(chat_id, self.toolset.def(v:true))
        endif

        if self.dispatcher.enqueue_query(chat_id, bot, message)
            call self.show_chat(chat_id)
        endif

        call self.ui.update_queue_size(self.dispatcher.queue_size())
    endfunction

    function! controller.send_warmup(force_new_chat, question, context) dict
        let [bot, question] = self.bots.select(a:question)
        let message = {
              \ "role"     : 'user',
              \ "sources"  : { "text": question },
              \ "bot_name" : bot.name()
        \ }

        let message = vimqq#fmt#fill_context(message, a:context, v:false)

        let chat_id = self.state.get_chat_id()

        if chat_id >= 0 && !a:force_new_chat
            let messages = self.chatsdb.get_messages(chat_id) + [message]
        else
            let messages = [message]
        endif

        call vimqq#log#debug('Sending warmup with message of ' . len(messages))
        call bot.send_warmup(messages)
    endfunction

    function! controller.show_list() dict
        let history = self.chatsdb.get_ordered_chats()
        call self.ui.display_chat_history(history, self.state.get_chat_id())
    endfunction

    function! controller.show_chat(chat_id) dict
        if !self.chatsdb.chat_exists(a:chat_id)
            call vimqq#log#error("Attempting to show non-existent chat")
            return
        endif
        call self.state.set_chat_id(a:chat_id)
        let messages = self.chatsdb.get_messages(a:chat_id)
        let partial  = self.chatsdb.get_partial(a:chat_id)
        call self.ui.display_chat(messages, partial)
    endfunction

    function! controller.fzf() dict
        call vimqq#fzf#show(self.chatsdb)
    endfunction

    return controller
endfunction

" Single controller instance
let s:controller = v:null

function! vimqq#main#setup()
    let s:controller = s:new()
    call s:controller.init()
endfunction

" -----------------------------------------------------------------------------
" Public API - functions called by defined public commands

function! vimqq#main#send_message(force_new_chat, question, context=v:null, use_index=v:false)
    call s:controller.send_message(a:force_new_chat, a:question, a:context, a:use_index)
endfunction

function! vimqq#main#send_warmup(force_new_chat, question, context=v:null)
    call s:controller.send_warmup(a:force_new_chat, a:question, a:context)
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