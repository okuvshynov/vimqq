if exists('g:autoloaded_vimqq_controller')
    finish
endif

let g:autoloaded_vimqq_controller = 1

" for situations when we use it in benchmarks/tests
let s:vqq_dbg_exit_on_turn_end = get(g:, 'vqq_dbg_exit_on_turn_end', v:false)
" directory to store chat history files
let g:vqq_chats_dir = get(g:, 'vqq_chats_dir', vimqq#platform#path#data('vqq_chats'))


function! vimqq#controller#new() abort
    let controller = {}

    " Move all script-level variables into controller
    let controller.ui      = v:null
    let controller.db      = v:null
    let controller.bots    = v:null
    let controller.state   = v:null
    let controller.toolset = v:null
    let controller.status  = v:null

    function! controller.init() dict
        let self.ui      = vimqq#ui#new()
        let self.db      = vimqq#db#new(g:vqq_chats_dir)
        let self.bots    = vimqq#bots#bots#new()
        let self.state   = vimqq#state#new(self.db)
        let self.toolset = vimqq#tools#toolset#new()
        let self.status  = vimqq#status#new()
        let self._in_flight = {}

        " to autoload and start command line monitoring
        call vimqq#warmup#start()

        " to start indexing
        " call vimqq#indexing#basic#run()
    endfunction

    function! controller.run_query(chat_id, bot, message) dict
        if has_key(self._in_flight, a:chat_id)
            call vimqq#sys_msg#info(a:chat_id, 'Try sending your message after assistant reply is complete')
            return v:false
        endif

        call vimqq#ttft#user_started_waiting(a:chat_id)
        " timestamp and other metadata might get appended here
        call self.db.append_message(a:chat_id, a:message)
        let chat = self.db.get_chat(a:chat_id)
        if a:bot.send_chat(chat)
            let self._in_flight[a:chat_id] = v:true
            return v:true
        else
            call vimqq#log#error('Unable to send message')
        endif
        return v:false
    endfunction

    " This function will be called when tool completed.
    function! controller.on_tool_result(bot, tool_result, chat_id) dict
        if self.run_query(a:chat_id, a:bot, a:tool_result)
            call self.show_chat(a:chat_id)
        endif

    endfunction

    function! controller.notify(event, args) dict
        if a:event ==# 'chat_selected'
            call self.show_chat(a:args['chat_id'])
            let bot_name = self.db.get_last_bot(a:args['chat_id'])
            if bot_name is v:null
                return
            endif
            let bot = self.bots.find(bot_name)
            if bot is v:null
                return
            endif
            if bot.warmup_on_select()
                call bot.send_warmup(self.db.get_messages(a:args['chat_id']))
            endif

            return
        endif

        if a:event ==# 'system_message'
            let chat_id = a:args['chat_id']
            let builder = vimqq#msg_builder#local().set_local(a:args['level'], a:args['text'])
            call self.db.append_message(chat_id, builder.msg)
            call self.show_chat(chat_id)
            return
        endif

        if a:event ==# 'reply_saved'
            let chat_id = a:args['chat_id']
            let bot = a:args['bot']
            let saved_msg = a:args['msg']
            
            call self.show_chat(chat_id)
            if has_key(self._in_flight, chat_id)
                unlet self._in_flight[chat_id]
            else
                vimqq#log#error('got a reply from non-enqueued query')
            endif

            let turn_end = v:true
            
            " check if we need to call tools
            let builder = vimqq#msg_builder#tool().set_bot_name(bot.name())
            if self.toolset.run(saved_msg, builder, {m -> self.on_tool_result(bot, m, chat_id)})
                let turn_end = v:false
            endif
    
            if !self.db.has_title(chat_id)
                let turn_end = v:false
                call self.db.set_title(chat_id, 'generating title...')
                call bot.send_gen_title(chat_id, self.db.get_first_message(chat_id))
            endif

            " Getting here means 'conversation turn end', input back to user
            " test/benchmark only behavior
            if s:vqq_dbg_exit_on_turn_end && turn_end
                cquit 0
            endif

            call self.show_chat(chat_id)
            return
        endif

        if a:event ==# 'warmup_done'
            call vimqq#warmup#done()
            return
        endif

        if a:event ==# 'delete_chat'
            let chat_id = a:args['chat_id']
            if !self.db.chat_exists(chat_id)
                call vimqq#log#warning("trying to delete non-existent chat")
                return
            endif
            let title = self.db.get_title(chat_id)
            let choice = confirm("Are you sure you want to delete '" . title . "'?", "&Yes\n&No", 2)
            if choice != 1
                return
            endif

            call self.db.delete_chat(chat_id)
            if self.state.get_chat_id() ==# chat_id
                call self.state.set_chat_id(-1)
            endif

            call self.show_list()
            return
        endif
        
        if a:event ==# 'chunk_done'
            if !self.db.chat_exists(a:args['chat_id'])
                call vimqq#log#warning("callback on non-existent chat.")
                return
            endif
            let chat_id = a:args['chat_id']
            let chat = self.db.get_chat(chat_id)
            let first = v:false
            if !has_key(chat, 'partial_message')
                let first = v:true
                call vimqq#ttft#first_token(chat_id)
                let chat['partial_message'] = a:args['builder'].msg
                call self.db._save()
            endif
            let chat.partial_message.bot_name = a:args['bot'].name()
            let chat.partial_message.seq_id = self.db.seq_id()
            if !has_key(chat.partial_message, 'seq_id_first')
                let chat.partial_message.seq_id_first = chat.partial_message.seq_id
            endif
            if a:args['chat_id'] ==# self.state.get_chat_id()
                if first
                    call self.show_chat(a:args['chat_id'])
                else
                    call self.ui.append_partial(a:args['chunk'])
                endif
            endif
            return
        endif
        
        if a:event ==# 'reply_done'
            call vimqq#util#log_chat(self.db._chats[a:args['chat_id']])
            if !self.db.chat_exists(a:args['chat_id'])
                call vimqq#log#warning('reply completed for non-existing (likely deleted) chat.')
                return
            endif
            let chat_id = a:args['chat_id']
            let chat = self.db.get_chat(chat_id)
            let msg = a:args['msg']
            if !has_key(chat, 'partial_message')
                let msg.seq_id = self.db.seq_id()
            else
                let msg.seq_id = self.db._chats[chat_id].partial_message.seq_id_first
            endif
            let msg.bot_name = a:args['bot'].name()
            let msg2 = self.db.append_message(chat_id, msg)
            call self.db.clear_partial(chat_id)
            call self.db._save()
            call vimqq#main#notify('reply_saved', {'chat_id': chat_id, 'bot': a:args['bot'], 'msg': msg2})
            return
        endif
        
        if a:event ==# 'title_done'
            if !self.db.chat_exists(a:args['chat_id'])
                call vimqq#log#warning("callback on non-existent chat.")
                return
            endif
            call self.db.set_title(a:args['chat_id'], a:args['title'])
            call vimqq#sys_msg#info(a:args.chat_id, 'Setting title: ' . a:args['title'])
            let bot = a:args['bot']
            if bot.warmup_on_select()
                call bot.send_warmup(self.db.get_messages(a:args['chat_id']))
            endif
            return
        endif
    endfunction

    function! controller.send_message(force_new_chat, question, context, use_index, use_tools=v:false) dict
        " pick the last used bot when:
        "   - no tag at the beginning of the message
        "   - no force_new_chat
        "   - previous chat exists
        let current_chat_id = self.state.get_chat_id()

        let current_bot = v:null
        if current_chat_id != -1 && !a:force_new_chat
            let current_bot = self.db.get_last_bot(current_chat_id)
        endif

        let [bot, question] = self.bots.select(a:question, current_bot)

        let builder = vimqq#msg_builder#user().set_bot_name(bot.name())
        let builder = builder.set_sources(question, a:context, a:use_index)

        let chat_id = self.state.pick_chat_id(a:force_new_chat)

        if a:use_index || a:use_tools
            call self.db.set_tools(chat_id, self.toolset.def())
        endif

        if self.run_query(chat_id, bot, builder.msg)
            call self.show_chat(chat_id)
        endif

    endfunction

    " This is a little confusing. There are two warmups:
    "   1. warmup when we started typing the question
    "   2. warmup when we opened a chat
    " (2) is handled by vimqq.warmup and it calls bot.send_warmup
    " directly. (1), on the other hand, while is initiated in vimqq.warmup,
    " goes through vimqq#warmup -> vimqq#main -> vimqq#controller path and
    " ends up here. This happens because we need to go through bot selection
    " process, and that happens here.
    function! controller.send_warmup(force_new_chat, question, context) dict
        let [bot, question] = self.bots.select(a:question)
        call vimqq#log#debug('send_warmup: [' . a:question . "] [" . bot.name() . "]")

        if !bot.warmup_on_typing()
            return v:false
        endif
        let builder = vimqq#msg_builder#user().set_bot_name(bot.name())
        let builder = builder.set_sources(question, a:context, v:false)

        let chat_id = self.state.get_chat_id()

        if chat_id >= 0 && !a:force_new_chat
            let messages = self.db.get_messages(chat_id) + [builder.msg]
        else
            let messages = [builder.msg]
        endif

        call vimqq#log#debug('Sending warmup with message of ' . len(messages))
        return bot.send_warmup(messages)
    endfunction

    function! controller.show_list() dict
        let history = self.db.get_ordered_chats()
        call self.ui.display_chat_history(history, self.state.get_chat_id())
    endfunction

    function! controller.show_chat(chat_id) dict
        if !self.db.chat_exists(a:chat_id)
            call vimqq#log#error("Attempting to show non-existent chat")
            return
        endif
        call self.state.set_chat_id(a:chat_id)
        let messages = self.db.get_messages(a:chat_id)
        let partial  = self.db.get_partial(a:chat_id)
        call self.ui.display_chat(messages, partial)
    endfunction

    function! controller.fzf() dict
        call vimqq#fzf#show(self.db)
    endfunction

    return controller
endfunction

