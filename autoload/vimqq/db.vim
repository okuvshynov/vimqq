" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_chatdb_module')
    finish
endif

let g:autoloaded_vimqq_chatdb_module = 1

function! s:max_seq_id(chat)
    let res = 0

    if has_key(a:chat, 'seq_id')
        let res = max([res, a:chat.seq_id])
    endif
    if has_key(a:chat.partial_message, 'seq_id')
        let res = max([res, a:chat.partial_message.seq_id])
    endif
    for message in a:chat.messages
        if has_key(message, 'seq_id')
            let res = max([res, message.seq_id])
        endif
    endfor
    return res
endfunction

function! vimqq#db#new(db_file) abort
    let db = {}
    let db._file = a:db_file
    let db._chats = {}

    " seq_id is autoincremented value assigned to chats, messages
    " and partial messages.
    let db._seq_id = 0

    if filereadable(db._file)
        let data = json_decode(join(readfile(db._file), ''))
        " Handle both old and new format
        if type(data) == v:t_dict && has_key(data, 'chats')
            " New format with metadata
            let db._chats = data.chats
            let db._seq_id = data.max_seq_id
        else
            " Old format - data is just chats
            let db._chats = data
            " Compute max_seq_id from chats
            for [key, chat] in items(db._chats)
                let db._seq_id = max([db._seq_id, s:max_seq_id(chat)])
            endfor
        endif
    endif

    function! db._save() dict
        let data = {
            \ 'chats': self._chats,
            \ 'max_seq_id': self._seq_id,
            \ 'schema_version': 1
            \ }
        let l:json_text = json_encode(data)
        silent! call writefile([l:json_text], self._file)
    endfunction

    function! db.seq_id() dict
        let self._seq_id = self._seq_id + 1
        return self._seq_id
    endfunction

    function! db.append_partial(chat_id, part) dict
        let self._chats[a:chat_id].partial_message.sources.text .= a:part
        let self._chats[a:chat_id].partial_message.seq_id = self.seq_id()
        if !has_key(self._chats[a:chat_id].partial_message, 'seq_id_first')
            let self._chats[a:chat_id].partial_message.seq_id_first = self._chats[a:chat_id].partial_message.seq_id
        endif

        call self._save()
    endfunction


    function! db.append_partial_tool_use(chat_id, tool_use) dict
        let self._chats[a:chat_id].partial_message.tool_use = a:tool_use
        let self._chats[a:chat_id].partial_message.seq_id = self.seq_id()
        call self._save()
    endfunction

    function! db.set_tools(chat_id, toolset) dict
        let self._chats[a:chat_id].tools_allowed = v:true
        let self._chats[a:chat_id].toolset = a:toolset
        call self._save()
    endfunction

    function! db.get_tools(chat_id) dict
        if has_key(self._chats, a:chat_id) && has_key(self._chats[a:chat_id], 'tools_allowed')
            return v:true
        endif
        return v:false
    endfunction

    function! db.delete_chat(chat_id) dict
        if has_key(self._chats, a:chat_id)
            call remove(self._chats, a:chat_id)
            call self._save()
        endif
    endfunction

    function! db.has_title(chat_id) dict
        return self._chats[a:chat_id].title_computed
    endfunction

    function! db.get_title(chat_id) dict
        return self._chats[a:chat_id].title
    endfunction

    function! db.get_chat(chat_id) dict
        return self._chats[a:chat_id]
    endfunction

    function! db.set_title(chat_id, title) dict
        let self._chats[a:chat_id].title          = a:title
        let self._chats[a:chat_id].title_computed = v:true
        let self._chats[a:chat_id].seq_id         = self.seq_id()
        call self._save()
    endfunction

    function! db.chat_exists(chat_id) dict
        return has_key(self._chats, a:chat_id)
    endfunction

    function! db.get_first_message(chat_id) dict
        return self._chats[a:chat_id].messages[0]
    endfunction

    function! db.append_message(chat_id, message) dict
        let message = copy(a:message)
        if !has_key(message, 'timestamp')
            let message['timestamp'] = localtime()
        endif

        if !has_key(message, 'seq_id')
            let message.seq_id = self.seq_id()
        endif
        let messages = self._chats[a:chat_id].messages
        let index = 0
        while index < len(messages)
            if messages[index].seq_id > message.seq_id
                break
            endif
            let index += 1
        endwhile

        call insert(messages, message, index)
        call self._save()

        return message
    endfunction

    function! db.get_last_bot(chat_id) dict
        if has_key(self._chats, a:chat_id)
            let messages = get(self._chats[a:chat_id], 'messages', [])
            let i = len(messages) - 1
            while i >= 0
                if messages[i].role ==# 'assistant'
                    return messages[i].bot_name
                endif
                let i = i - 1
            endwhile
        endif
        return v:null
    endfunction

    function! db.get_ordered_chats() dict
        let chat_list = []
        for [key, chat] in items(self._chats)
            let chat_list += [{
                \ 'title': chat.title, 
                \ 'id': chat.id,
                \ 'time': s:max_seq_id(chat),
                \ 'messages' : chat.messages
            \ }]
        endfor
        return sort(chat_list, {a, b -> a.time > b.time ? - 1 : a.time < b.time ? 1 : 0})
    endfunction

    " We return a reference here, not a copy.
    function! db.get_messages(chat_id) dict
        return self._chats[a:chat_id].messages
    endfunction

    function! db.chat_len(chat_id) dict
        let res = 0
        for message in self._chats[a:chat_id].messages
            if message.role !=# 'local'
                let res = res + 1
            endif
        endfor
        return res
    endfunction

    function! db.get_partial(chat_id) dict
        return self._chats[a:chat_id].partial_message
    endfunction

    function! db.clear_partial(chat_id) dict
        let self._chats[a:chat_id].partial_message = {"role": "assistant", "sources": { "text": ""}}
        call self._save()
    endfunction

    function! db.reset_partial(chat_id, bot_name) dict
        let self._chats[a:chat_id].partial_message = {"role": "assistant", "sources": { "text": ""}, "bot_name": a:bot_name, "timestamp": localtime()}
        call self._save()
    endfunction

    function! db.partial_done(chat_id) dict
        let message = deepcopy(self._chats[a:chat_id].partial_message)
        let message.seq_id = message.seq_id_first
        call self.append_message(a:chat_id, message)
        call self.clear_partial(a:chat_id)
        call self._save()
    endfunction

    function! db.new_chat() dict
        let chat = {}
        let chat.id = self.seq_id()
        let chat.messages = []
        let chat.title = "new chat"
        let chat.title_computed = v:false
        let chat.timestamp = localtime()
        let chat.seq_id = chat.id

        let self._chats[chat.id] = chat
        call self.clear_partial(chat.id)

        call self._save()

        return chat.id
    endfunction

    function! db.handle_event(event, args) dict
        if a:event ==# 'tool_use_recv'
            if !self.chat_exists(a:args['chat_id'])
                call vimqq#log#warning("callback on non-existent chat.")
                return
            endif
            call self.append_partial_tool_use(a:args['chat_id'], a:args['tool_use'])
            return
        endif
        if a:event ==# 'chunk_done'
            if !self.chat_exists(a:args['chat_id'])
                call vimqq#log#warning("callback on non-existent chat.")
                return
            endif
            if empty(self.get_partial(a:args['chat_id']).sources.text)
                call vimqq#metrics#first_token(a:args['chat_id'])
            endif
            call self.append_partial(a:args['chat_id'], a:args['chunk'])
            call vimqq#events#notify('chunk_saved', a:args)
            return
        endif
        if a:event ==# 'reply_done'
            if !self.chat_exists(a:args['chat_id'])
                call vimqq#log#warning('reply completed for non-existing (likely deleted) chat.')
                return
            endif
            let chat_id = a:args['chat_id']
            let msg = a:args['msg']
            let msg.seq_id = self._chats[chat_id].partial_message.seq_id_first
            let msg.bot_name = a:args['bot'].name()
            call self.append_message(chat_id, msg)
            call self.clear_partial(chat_id)
            call self._save()
            call vimqq#events#notify('reply_saved', {'chat_id': chat_id, 'bot': a:args['bot']})
            return
        endif
        if a:event ==# 'title_done'
            if !self.chat_exists(a:args['chat_id'])
                call vimqq#log#warning("callback on non-existent chat.")
                return
            endif
            call self.set_title(a:args['chat_id'], a:args['title'])
            call vimqq#events#notify('title_saved', {'chat_id': a:args['chat_id']})
            call vimqq#sys_msg#info(a:args.chat_id, 'Setting title: ' . a:args['title'])
        endif

    endfunction

    return db
endfunction

