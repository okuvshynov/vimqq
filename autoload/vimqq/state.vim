if exists('g:autoloaded_vimqq_state')
    finish
endif

let g:autoloaded_vimqq_state = 1

function! vimqq#state#new(db) abort
    let l:state = {}
    
    let l:state._db     = a:db
    let l:state._dispatcher = vimqq#dispatcher#new(a:db)  
    let l:state._latencies = {}
    let l:state._last_bot_name = ""
    
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
        let [l:sent, l:last_bot_name] = self._dispatcher.reply_complete(a:chat_id)
        let self._last_bot_name = l:last_bot_name
        return l:sent
    endfunction

    " TODO: this needs to be moved to metrics
    function! l:state.user_started_waiting(chat_id) dict
        if exists('*reltime')
            let self._latencies[a:chat_id] = reltime()
        endif
    endfunction

    function! l:state.first_token(chat_id) dict
        if exists('*reltime')
            if has_key(self._latencies, a:chat_id)
                let latency = reltimefloat(reltime(self._latencies[a:chat_id]))
                call vimqq#log#info(printf('TTFT %.3f s', latency))
                unlet self._latencies[a:chat_id]
            else
                " TODO: this tracking is wrong in case of non-empty queue
                " as we would unlet the start point for both messages
                call vimqq#log#info('token for chat with no start point.')
            endif
        endif
    endfunction

    function! l:state.last_bot_name() dict
       return self._last_bot_name 
    endfunction

    return l:state
endfunction
