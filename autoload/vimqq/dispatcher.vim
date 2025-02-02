if exists('g:autoloaded_vimqq_dispatcher')
    finish
endif

let g:autoloaded_vimqq_dispatcher = 1

function! vimqq#dispatcher#new(db) abort
    let dispatcher = {}
    
    let dispatcher._db = a:db
    let dispatcher._in_flight = {}

    function! dispatcher.queue_size() dict
        return len(self._in_flight)
    endfunction 

    function! dispatcher.enqueue_query(chat_id, bot, message) dict
        if has_key(self._in_flight, a:chat_id)
            call vimqq#sys_msg#info(a:chat_id, 'Try sending your message after assistant reply is complete')
            return v:false
        endif

        call vimqq#metrics#user_started_waiting(a:chat_id)
        " timestamp and other metadata might get appended here
        call self._db.append_message(a:chat_id, a:message)
        call self._db.reset_partial(a:chat_id, a:bot.name())
        let chat = self._db.get_chat(a:chat_id)
        if a:bot.send_chat(chat)
            let self._in_flight[a:chat_id] = v:true
            return v:true
        else
            call vimqq#log#error('Unable to send message')
        endif
        return v:false
    endfunction

    function! dispatcher.reply_complete(chat_id) dict
        if has_key(self._in_flight, a:chat_id)
            unlet self._in_flight[a:chat_id]
        else
            vimqq#log#error('got a reply from non-enqueued query')
        endif
    endfunction

    return dispatcher
endfunction
