let g:vqq#ChatsDB = {}

function! g:vqq#ChatsDB.new(chats_file) dict
    let l:instance = copy(self)
    let l:instance._file = a:chats_file
    let l:instance._chats = {}
    if filereadable(a:chats_file)
        let l:instance._chats = json_decode(join(readfile(a:chats_file), ''))
    endif
    return l:instance
endfunction

function! g:vqq#ChatsDB.init() dict
endfunction

function! g:vqq#ChatsDB._save() dict
    let l:chats_text = json_encode(self._chats)
    silent! call writefile([l:chats_text], self._file)
endfunction

function! g:vqq#ChatsDB.append_partial(chat_id, part) dict
    let self._chats[a:chat_id].partial_message.content .= a:part
    call self._save()
endfunction

function! g:vqq#ChatsDB.has_title(chat_id) dict
    return self._chats[a:chat_id].title_computed
endfunction

function! g:vqq#ChatsDB.set_title(chat_id, title) dict
    let self._chats[a:chat_id].title          = a:title
    let self._chats[a:chat_id].title_computed = v:true
    call self._save()
endfunction

function! g:vqq#ChatsDB.get_first_message(chat_id) dict
    return self._chats[a:chat_id].messages[0].content
endfunction

function! g:vqq#ChatsDB.append_message(chat_id, message) dict
    let l:message = copy(a:message)
    if !has_key(l:message, 'timestamp')
        let l:message['timestamp'] = localtime()
    endif

    call add(self._chats[a:chat_id].messages, l:message)
    call self._save()

    return l:message
endfunction

function! g:vqq#ChatsDB._last_updated(chat) dict
    let l:time = a:chat.timestamp
    for l:message in reverse(copy(a:chat.messages))
        if has_key(l:message, 'timestamp')
            let l:time = l:message.timestamp
            break
        endif
    endfor
    return l:time
endfunction

function! g:vqq#ChatsDB.get_ordered_chats() dict
    let l:chat_list = []
    for [key, chat] in items(self._chats)
        let l:chat_list += [{'title': chat.title, 'id': chat.id, 'time': self._last_updated(chat)}]
    endfor
    return sort(l:chat_list, {a, b -> a.time > b.time ? - 1 : a.time < b.time ? 1 : 0})
endfunction

" TODO - should we return a copy and not a reference?
function! g:vqq#ChatsDB.get_messages(chat_id) dict
    return self._chats[a:chat_id].messages
endfunction

function! g:vqq#ChatsDB.get_partial(chat_id) dict
    return self._chats[a:chat_id].partial_message
endfunction

function! g:vqq#ChatsDB.clear_partial(chat_id) dict
  let self._chats[a:chat_id].partial_message = {"role": "assistant", "content": ""}
endfunction

function! g:vqq#ChatsDB.reset_partial(chat_id, bot_name) dict
  let self._chats[a:chat_id].partial_message = {"role": "assistant", "content": "", "bot_name": a:bot_name, "timestamp": localtime()}
endfunction

function! g:vqq#ChatsDB.partial_done(chat_id) dict
    call self.append_message(a:chat_id, self._chats[a:chat_id].partial_message)
    call self.clear_partial(a:chat_id)
endfunction

function! g:vqq#ChatsDB.new_chat()
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

