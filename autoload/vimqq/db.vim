" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_chatdb_module')
    finish
endif

let g:autoloaded_vimqq_chatdb_module = 1

" Set the default chats directory
let g:vqq_chats_dir = get(g:, 'vqq_chats_dir', vimqq#platform#path#data('vqq_chats'))
let s:metadata_file = 'metadata.json'

function! s:ensure_dir_exists(dir)
    if !isdirectory(a:dir)
        call mkdir(a:dir, 'p')
    endif
endfunction

function! s:chat_file(dir, chat_id)
    return a:dir . '/chat_' . a:chat_id . '.json'
endfunction

function! s:max_seq_id(chat)
    let res = 0

    if has_key(a:chat, 'seq_id')
        let res = max([res, a:chat.seq_id])
    endif
    if has_key(a:chat, 'partial_message')
        if has_key(a:chat.partial_message, 'seq_id')
            let res = max([res, a:chat.partial_message.seq_id])
        endif
    endif
    for message in a:chat.messages
        if has_key(message, 'seq_id')
            let res = max([res, message.seq_id])
        endif
    endfor
    return res
endfunction

function! vimqq#db#new(db_file) abort
    " The db_file parameter is now treated as the directory where chats will be stored
    " If it ends with a .json extension, we'll use the directory containing that file
    let db = {}
    
    " Determine the directory to store chats
    if a:db_file =~# '\.json$'
        " If a JSON file is provided (legacy), use the parent directory
        let db._chats_dir = fnamemodify(a:db_file, ':h') . '/vqq_chats'
        let db._legacy_file = a:db_file
    else
        " Otherwise use the provided directory
        let db._chats_dir = a:db_file
        let db._legacy_file = ''
    endif
    
    " Ensure the directory exists
    call s:ensure_dir_exists(db._chats_dir)
    
    " Path to metadata file
    let db._metadata_file = db._chats_dir . '/' . s:metadata_file
    
    " Initialize chats dict and seq_id
    let db._chats = {}
    let db._seq_id = 0
    
    " Try to load the metadata file first
    if filereadable(db._metadata_file)
        let metadata = json_decode(join(readfile(db._metadata_file), ''))
        let db._seq_id = metadata.max_seq_id
    elseif db._legacy_file != '' && filereadable(db._legacy_file)
        " Handle migration from old single-file format
        call vimqq#log#info('Migrating from legacy DB format to individual chat files')
        let data = json_decode(join(readfile(db._legacy_file), ''))
        
        " Handle both old and new format of the legacy file
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
        
        " Migrate each chat to individual file
        for [chat_id, chat] in items(db._chats)
            let chat_file = s:chat_file(db._chats_dir, chat_id)
            call writefile([json_encode(chat)], chat_file)
        endfor
        
        " Save metadata
        call db._save_metadata()
    endif
    
    " Load all chat files
    for chat_file in glob(db._chats_dir . '/chat_*.json', 0, 1)
        let chat_id_match = matchstr(chat_file, 'chat_\zs\d\+\ze\.json')
        if !empty(chat_id_match)
            let chat_id = str2nr(chat_id_match)
            let chat_data = json_decode(join(readfile(chat_file), ''))
            let db._chats[chat_id] = chat_data
        endif
    endfor
    
    function! db._save_metadata() dict
        let metadata = {
            \ 'max_seq_id': self._seq_id,
            \ 'schema_version': 2
            \ }
        let l:json_text = json_encode(metadata)
        silent! call writefile([l:json_text], self._metadata_file)
    endfunction
    
    function! db._save_chat(chat_id) dict
        let chat_file = s:chat_file(self._chats_dir, a:chat_id)
        let chat_data = self._chats[a:chat_id]
        silent! call writefile([json_encode(chat_data)], chat_file)
    endfunction
    
    function! db._save() dict
        " Save metadata
        call self._save_metadata()
        
        " Save each chat to its individual file
        for [chat_id, chat] in items(self._chats)
            call self._save_chat(chat_id)
        endfor
    endfunction

    function! db.seq_id() dict
        let self._seq_id = self._seq_id + 1
        call self._save_metadata()
        return self._seq_id
    endfunction

    function! db.set_tools(chat_id, toolset) dict
        let self._chats[a:chat_id].tools_allowed = v:true
        let self._chats[a:chat_id].toolset = a:toolset
        call self._save_chat(a:chat_id)
    endfunction

    function! db.get_tools(chat_id) dict
        if has_key(self._chats, a:chat_id) && has_key(self._chats[a:chat_id], 'tools_allowed')
            return v:true
        endif
        return v:false
    endfunction

    function! db.delete_chat(chat_id) dict
        if has_key(self._chats, a:chat_id)
            let chat_file = s:chat_file(self._chats_dir, a:chat_id)
            if filereadable(chat_file)
                call delete(chat_file)
            endif
            call remove(self._chats, a:chat_id)
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
        call self._save_chat(a:chat_id)
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
        call self._save_chat(a:chat_id)

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
        return get(self._chats[a:chat_id], 'partial_message', v:null)
    endfunction

    function! db.clear_partial(chat_id) dict
        if has_key(self._chats[a:chat_id], 'partial_message')
            unlet self._chats[a:chat_id]['partial_message']
            call self._save_chat(a:chat_id)
        endif
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
        call self._save_chat(chat.id)

        return chat.id
    endfunction

    return db
endfunction

