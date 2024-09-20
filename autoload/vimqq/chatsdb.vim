" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_chatdb_module')
    finish
endif

let g:autoloaded_vimqq_chatdb_module = 1

" file to store all message history
let g:vqq_chats_file = get(g:, 'vqq_chats_file', vimqq#path#data('vqq_chats.json'))

function! vimqq#chatsdb#new() abort
    let l:db = {}
    let l:db._file = g:vqq_chats_file
    let l:db._chats = {}
    if filereadable(l:db._file)
        let l:db._chats = json_decode(join(readfile(l:db._file), ''))
    endif

    function! l:db._save() dict
        let l:chats_text = json_encode(self._chats)
        silent! call writefile([l:chats_text], self._file)
    endfunction

    function! l:db.append_partial(chat_id, part) dict
        let self._chats[a:chat_id].partial_message.content .= a:part
        call self._save()
    endfunction

    function! l:db.delete_chat(chat_id) dict
        if has_key(self._chats, a:chat_id)
            call remove(self._chats, a:chat_id)
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

    function! l:db.set_title(chat_id, title) dict
        let self._chats[a:chat_id].title          = a:title
        let self._chats[a:chat_id].title_computed = v:true
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

        call add(self._chats[a:chat_id].messages, l:message)
        call self._save()

        return l:message
    endfunction

    function! l:db._last_updated(chat) dict
        let l:time = a:chat.timestamp
        for l:message in reverse(copy(a:chat.messages))
            if has_key(l:message, 'timestamp')
                let l:time = l:message.timestamp
                break
            endif
        endfor
        return l:time
    endfunction

    function! l:db.get_ordered_chats() dict
        let l:chat_list = []
        for [key, chat] in items(self._chats)
            let l:chat_list += [{'title': chat.title, 'id': chat.id, 'time': self._last_updated(chat)}]
        endfor
        return sort(l:chat_list, {a, b -> a.time > b.time ? - 1 : a.time < b.time ? 1 : 0})
    endfunction

    " We return a reference here, not a copy.
    function! l:db.get_messages(chat_id) dict
        return self._chats[a:chat_id].messages
    endfunction

    function! l:db.get_partial(chat_id) dict
        return self._chats[a:chat_id].partial_message
    endfunction

    function! l:db.clear_partial(chat_id) dict
        let self._chats[a:chat_id].partial_message = {"role": "assistant", "content": ""}
        call self._save()
    endfunction

    function! l:db.reset_partial(chat_id, bot_name) dict
        let self._chats[a:chat_id].partial_message = {"role": "assistant", "content": "", "bot_name": a:bot_name, "timestamp": localtime()}
        call self._save()
    endfunction

    function! l:db.partial_done(chat_id) dict
        let l:message = deepcopy(self._chats[a:chat_id].partial_message)
        let l:message.message = l:message.content
        let l:message.content = ""
        
        call self.append_message(a:chat_id, l:message)
        call self.clear_partial(a:chat_id)
        call self._save()
    endfunction

    function! l:db.new_chat()
        let l:chat = {}
        let l:chat.id = empty(self._chats) ? 1 : max(keys(self._chats)) + 1
        let l:chat.messages = []
        let l:chat.title = "new chat"
        let l:chat.title_computed = v:false
        let l:chat.timestamp = localtime()

        let self._chats[l:chat.id] = l:chat
        call self.clear_partial(l:chat.id)

        call self._save()

        return l:chat.id
    endfunction

    return l:db
endfunction

