" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_chatdb_module')
    finish
endif

let g:autoloaded_vimqq_chatdb_module = 1

" file to store all message history
let g:vqq_chats_file = get(g:, 'vqq_chats_file', vimqq#platform#path#data('vqq_chats.json'))

function! vimqq#chatsdb#new() abort
    let l:db = {}
    let l:db._file = g:vqq_chats_file
    let l:db._chats = {}

    " seq_id is autoincremented value assigned to chats, messages
    " and partial messages.
    let l:db._seq_id = 0

    function! l:db._max_seq_id(chat) dict
        let res = 0

        if has_key(a:chat, 'seq_id')
            let res = max([res, a:chat.seq_id])
        endif
        if has_key(a:chat.partial_message, 'seq_id')
            let res = max([res, a:chat.partial_message.seq_id])
        endif
        for message in a:chat.messages
            if has_key(l:message, 'seq_id')
                let res = max([res, l:message.seq_id])
            endif
        endfor
        return res
    endfunction

    if filereadable(l:db._file)
        let l:data = json_decode(join(readfile(l:db._file), ''))
        " Handle both old and new format
        if type(l:data) == v:t_dict && has_key(l:data, 'chats')
            " New format with metadata
            let l:db._chats = l:data.chats
            let l:db._seq_id = l:data.max_seq_id
        else
            " Old format - data is just chats
            let l:db._chats = l:data
            " Compute max_seq_id from chats
            for [key, chat] in items(l:db._chats)
                let l:db._seq_id = max([l:db._seq_id, l:db._max_seq_id(chat)])
            endfor
        endif
    endif

    function! l:db._save() dict
        let l:data = {
            \ 'chats': self._chats,
            \ 'max_seq_id': self._seq_id,
            \ 'schema_version': 1
            \ }
        let l:json_text = json_encode(l:data)
        silent! call writefile([l:json_text], self._file)
    endfunction

    function! l:db.seq_id() dict
        let self._seq_id = self._seq_id + 1
        return self._seq_id
    endfunction

    function! l:db.append_partial(chat_id, part) dict
        let self._chats[a:chat_id].partial_message.sources.text .= a:part
        let self._chats[a:chat_id].partial_message.seq_id = self.seq_id()
        call self._save()
    endfunction


    function! l:db.append_partial_tool_use(chat_id, tool_use) dict
        let self._chats[a:chat_id].partial_message.tool_use = a:tool_use
        let self._chats[a:chat_id].partial_message.seq_id = self.seq_id()
        call self._save()

    endfunction

    function! l:db.set_tools(chat_id, toolset) dict
        let self._chats[a:chat_id].tools_allowed = v:true
        let self._chats[a:chat_id].toolset = a:toolset
        call self._save()
    endfunction

    function! l:db.get_tools(chat_id) dict
        if has_key(self._chats, a:chat_id) && has_key(self._chats[a:chat_id], 'tools_allowed')
            return v:true
        endif
        return v:false
    endfunction

    function! l:db.delete_chat(chat_id) dict
        if has_key(self._chats, a:chat_id)
            call remove(self._chats, a:chat_id)
            call self._save()
        endif
    endfunction

    function! l:db.has_title(chat_id) dict
        return self._chats[a:chat_id].title_computed
    endfunction

    function! l:db.is_empty(chat_id) dict
        return empty(self._chats[a:chat_id].messages)
    endfunction

    function! l:db.get_title(chat_id) dict
        return self._chats[a:chat_id].title
    endfunction

    function! l:db.get_chat(chat_id) dict
        return self._chats[a:chat_id]
    endfunction

    function! l:db.set_title(chat_id, title) dict
        let self._chats[a:chat_id].title          = a:title
        let self._chats[a:chat_id].title_computed = v:true
        let self._chats[a:chat_id].seq_id         = self.seq_id()
        call self._save()
    endfunction

    function! l:db.chat_exists(chat_id) dict
        return has_key(self._chats, a:chat_id)
    endfunction

    function! l:db.get_first_message(chat_id) dict
        return self._chats[a:chat_id].messages[0]
    endfunction

    function! l:db.append_message(chat_id, message) dict
        let l:message = copy(a:message)
        if !has_key(l:message, 'timestamp')
            let l:message['timestamp'] = localtime()
        endif

        let l:message.seq_id = self.seq_id()

        call add(self._chats[a:chat_id].messages, l:message)
        call self._save()

        return l:message
    endfunction

    function! l:db.get_ordered_chats() dict
        let l:chat_list = []
        for [key, chat] in items(self._chats)
            let l:chat_list += [{'title': chat.title, 'id': chat.id, 'time': self._max_seq_id(chat)}]
        endfor
        return sort(l:chat_list, {a, b -> a.time > b.time ? - 1 : a.time < b.time ? 1 : 0})
    endfunction

    function! l:db.get_ordered_chats_with_messages() dict
        let l:chat_list = []
        for [key, chat] in items(self._chats)
            let l:chat_list += [{'title': chat.title, 'id': chat.id, 'time': self._max_seq_id(chat), 'messages' : chat.messages}]
        endfor
        return sort(l:chat_list, {a, b -> a.time > b.time ? - 1 : a.time < b.time ? 1 : 0})
    endfunction

    " We return a reference here, not a copy.
    function! l:db.get_messages(chat_id) dict
        return self._chats[a:chat_id].messages
    endfunction

    function! l:db.chat_len(chat_id) dict
        return len(self._chats[a:chat_id].messages)
    endfunction

    function! l:db.get_partial(chat_id) dict
        return self._chats[a:chat_id].partial_message
    endfunction

    function! l:db.clear_partial(chat_id) dict
        let self._chats[a:chat_id].partial_message = {"role": "assistant", "sources": { "text": ""}}
        call self._save()
    endfunction

    function! l:db.reset_partial(chat_id, bot_name) dict
        let self._chats[a:chat_id].partial_message = {"role": "assistant", "sources": { "text": ""}, "bot_name": a:bot_name, "timestamp": localtime()}
        call self._save()
    endfunction

    function! l:db.partial_done(chat_id) dict
        let l:message = deepcopy(self._chats[a:chat_id].partial_message)
        call self.append_message(a:chat_id, l:message)
        call self.clear_partial(a:chat_id)
        call self._save()
    endfunction

    function! l:db.new_chat() dict
        let l:chat = {}
        let l:chat.id = self.seq_id()
        let l:chat.messages = []
        let l:chat.title = "new chat"
        let l:chat.title_computed = v:false
        let l:chat.timestamp = localtime()
        let l:chat.seq_id = l:chat.id

        let self._chats[l:chat.id] = l:chat
        call self.clear_partial(l:chat.id)

        call self._save()

        return l:chat.id
    endfunction

    function! l:db.handle_event(event, args) dict
        if a:event ==# 'tool_use_recv'
            if !self.chat_exists(a:args['chat_id'])
                call vimqq#log#info("callback on non-existent chat.")
                return
            endif
            call self.append_partial_tool_use(a:args['chat_id'], a:args['tool_use'])
            return
        endif
        if a:event ==# 'chunk_done'
            if !self.chat_exists(a:args['chat_id'])
                call vimqq#log#info("callback on non-existent chat.")
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
                call vimqq#log#info('reply completed for non-existing (likely deleted) chat.')
                return
            endif
            call self.partial_done(a:args['chat_id'])
            call vimqq#events#notify('reply_saved', {'chat_id': a:args['chat_id'], 'bot': a:args['bot']})
            return
        endif
        if a:event ==# 'title_done'
            if !self.chat_exists(a:args['chat_id'])
                call vimqq#log#info("callback on non-existent chat.")
                return
            endif
            call self.set_title(a:args['chat_id'], a:args['title'])
            call vimqq#events#notify('title_saved', {'chat_id': a:args['chat_id']})
        endif

    endfunction

    return l:db
endfunction

