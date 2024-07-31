if exists('g:autoloaded_vimqq_state')
    finish
endif

let g:autoloaded_vimqq_state = 1

function! vimqq#state#new(db) abort
    let l:state = {}
    
    let l:state._db     = a:db
    let l:state._queues = {}
    
    " this is the active chat id. New queries would go to this chat by default
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
        let l:size = 0
        for l:queue in values(self._queues)
          let l:size += len(l:queue)
        endfor
        return l:size
    endfunction 

    " returns
    "   - v:true if query started running immidiately
    "   - v:false if query was enqueued
    function! l:state.enqueue_query(chat_id, bot, message) dict
        let l:queue = get(self._queues, a:chat_id, [])
        let l:sent  = v:false
        if empty(l:queue)
            " timestamp and other metadata might get appended here
            call self._db.append_message(a:chat_id, a:message)
            call self._db.reset_partial(a:chat_id, a:bot.name())
            if a:bot.send_chat(a:chat_id, self._db.get_messages(a:chat_id))
                call add(l:queue, [a:message, a:bot])
                let l:sent = v:true
            else
                call vimqq#log#error('Unable to send message')
            endif
        else
            call add(l:queue, [a:message, a:bot])
        endif
        let self._queues[a:chat_id] = l:queue
        return l:sent
    endfunction

    function! l:state.reply_complete(chat_id) dict
        " remove from queue
        let l:sent  = v:false
        let l:queue = get(self._queues, a:chat_id, [])

        if empty(l:queue)
            vimqq#log#error('got a reply from non-enqueued query')
            return v:false
        endif
        call remove(l:queue, 0)

        " kick off the next request if there was one
        if !empty(l:queue)
            let [l:message, l:bot] = remove(l:queue, 0)
            call self._db.append_message(a:chat_id, l:message)
            call self._db.reset_partial(a:chat_id, l:bot.name())
            if l:bot.send_chat(a:chat_id, self._db.get_messages(a:chat_id))
                let l:queue = [[l:message, l:bot]] + l:queue
                let l:sent = v:true
            else
                call vimqq#log#error('Unable to send message')
            endif
        endif
        let self._queues[a:chat_id] = l:queue
        return l:sent
    endfunction

    return l:state
endfunction
