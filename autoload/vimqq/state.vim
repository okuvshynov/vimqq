if exists('g:autoloaded_vimqq_state')
    finish
endif

let g:autoloaded_vimqq_state = 1

function! vimqq#state#new(db) abort
    let l:state = {}
    
    let l:state._db     = a:db
    let l:state._dispatcher = vimqq#dispatcher#new(a:db)  
    
    " this is the active chat id. 
    " New queries would go to this chat by default
    " 'active' means 'in the chat view buffer', even 
    " if buffer is not visible
    let l:state._curr_chat_id = -1

    function l:state.get_chat_id() dict
        return self._curr_chat_id
    endfunction

    function l:state.set_chat_id(chat_id) dict
        let self._curr_chat_id = a:chat_id
    endfunction

    function l:state._get_or_create_chat_id() dict
        if self._curr_chat_id == -1
            let self._curr_chat_id = self._db.new_chat()
        endif
        return self._curr_chat_id
    endfunction

    function l:state.pick_chat_id(force_new_chat) dict
        if a:force_new_chat
            return self._db.new_chat()
        else
            return self._get_or_create_chat_id() 
        endif
    endfunction

    function! l:state.queue_size() dict
        return self._dispatcher.queue_size()
    endfunction 

    " returns
    "   - v:true if query started running immediately
    "   - v:false if query was enqueued
    function! l:state.enqueue_query(chat_id, bot, message) dict
        return self._dispatcher.enqueue_query(a:chat_id, a:bot, a:message)
    endfunction

    function! l:state.reply_complete(chat_id) dict
        return self._dispatcher.reply_complete(a:chat_id)
    endfunction

    return l:state
endfunction
