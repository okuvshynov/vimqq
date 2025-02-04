if exists('g:autoloaded_vimqq_state')
    finish
endif

let g:autoloaded_vimqq_state = 1

function! vimqq#state#new(db) abort
    let state = {}
    
    let state._db = a:db
    
    " New queries would go to this chat by default
    " 'active' means 'in the chat view buffer', even if buffer is not visible
    let state._curr_chat_id = -1

    function state.get_chat_id() dict
        return self._curr_chat_id
    endfunction

    function state.set_chat_id(chat_id) dict
        let self._curr_chat_id = a:chat_id
    endfunction

    function state._get_or_create_chat_id() dict
        if self._curr_chat_id == -1
            let self._curr_chat_id = self._db.new_chat()
        endif
        return self._curr_chat_id
    endfunction

    function state.pick_chat_id(force_new_chat) dict
        if a:force_new_chat
            return self._db.new_chat()
        else
            return self._get_or_create_chat_id() 
        endif
    endfunction

    return state
endfunction
