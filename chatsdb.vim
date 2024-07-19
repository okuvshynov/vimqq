let g:vqq#ChatsDB = {}

function! g:vqq#ChatsDB.new(sessions_file) dict
    let l:instance = copy(self)
    let l:instance._file = a:sessions_file
    if filereadable(a:sessions_file)
        let l:instance._chats = json_decode(join(readfile(a:sessions_file), ''))
    endif
    return l:instance
endfunction

function! g:vqq#ChatsDB.init() dict
endfunction

function! g:vqq#ChatsDB._save() dict
    let l:sessions_text = json_encode(self._chats)
    silent! call writefile([l:sessions_text], self._file)
endfunction

function! g:vqq#ChatsDB.append_partial(session_id, part) dict
    call add(self._chats[a:session_id].partial_reply, a:part)
    call self._save()
endfunction

function! g:vqq#ChatsDB.has_title(session_id) dict
    return self._chats[a:session_id].title_computed
endfunction

function! g:vqq#ChatsDB.set_title(session_id, title) dict
    let self._chats[a:session_id].title          = a:title
    let self._chats[a:session_id].title_computed = v:true
    call self._save()
endfunction

function! g:vqq#ChatsDB.get_first_message(session_id) dict
    return self._chats[a:session_id].messages[0].content
endfunction

function! g:vqq#ChatsDB.append_message(session_id, message) dict
    let l:message = copy(a:message)
    if !has_key(l:message, 'timestamp')
        let l:message['timestamp'] = localtime()
    endif

    call add(self._chats[a:session_id].messages, l:message)
    call self._save()

    return l:message
endfunction

function! g:vqq#ChatsDB._last_updated(session) dict
    let l:time = a:session.timestamp
    for l:message in reverse(copy(a:session.messages))
        if has_key(l:message, 'timestamp')
            let l:time = l:message.timestamp
            break
        endif
    endfor
    return l:time
endfunction

function! g:vqq#ChatsDB.get_ordered_chats() dict
    let l:session_list = []
    for [key, session] in items(self._chats)
        let l:session_list += [{'title': session.title, 'id': session.id, 'time': self._last_updated(session)}]
    endfor
    return sort(l:session_list, {a, b -> a.time > b.time ? - 1 : a.time < b.time ? 1 : 0})
endfunction

" TODO - should we return a copy and not a reference?
function! g:vqq#ChatsDB.get_messages(session_id) dict
    return self._chats[a:session_id].messages
endfunction

function! g:vqq#ChatsDB.get_partial(session_id) dict
    return join(self._chats[a:session_id].partial_reply, '')
endfunction

function! g:vqq#ChatsDB.clear_partial(session_id) dict
    let self._chats[a:session_id].partial_reply = []
endfunction

function! g:vqq#ChatsDB.partial_done(session_id) dict
    let l:reply = join(self._chats[a:session_id].partial_reply, '')
    call self.append_message(a:session_id, {"role": "assistant", "content": l:reply})
    let self._chats[a:session_id].partial_reply = []
endfunction

function! g:vqq#ChatsDB.new_chat()
    let l:session = {}
    let l:session.id = empty(self._chats) ? 1 : max(keys(self._chats)) + 1
    let l:session.messages = []
    let l:session.partial_reply = []
    let l:session.title = "new chat"
    let l:session.title_computed = v:false
    let l:session.timestamp = localtime()

    let self._chats[l:session.id] = l:session

    call self._save()

    return l:session.id
endfunction

