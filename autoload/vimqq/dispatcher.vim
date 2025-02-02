if exists('g:autoloaded_vimqq_dispatcher')
    finish
endif

" dispatcher needs to take into account two things:
" - chat-level queueing, so that we have alternate turns
" - bot-level prioritization, so, for example, we stop warmup
"   if user initiates new query. Does llama.cpp server support cancel?
let g:autoloaded_vimqq_dispatcher = 1

function! vimqq#dispatcher#new(db) abort
    let dispatcher = {}
    
    let dispatcher._db = a:db
    let dispatcher._queues = {}

    " returns total size of all queues
    function! dispatcher.queue_size() dict
        let res = 0
        for queue in values(self._queues)
          let res += len(queue)
        endfor
        return res
    endfunction 

    " returns
    "   - v:true if query started running immediately
    "   - v:false if chat wasn't sent
    function! dispatcher.enqueue_query(chat_id, bot, message) dict
        let queue = get(self._queues, a:chat_id, [])
        let sent = v:false
        if empty(queue)
            call vimqq#metrics#user_started_waiting(a:chat_id)
            " timestamp and other metadata might get appended here
            call self._db.append_message(a:chat_id, a:message)
            call self._db.reset_partial(a:chat_id, a:bot.name())
            let chat = self._db.get_chat(a:chat_id)
            if a:bot.send_chat(chat)
                call add(queue, [a:message, a:bot])
                let sent = v:true
            else
                call vimqq#log#error('Unable to send message')
            endif
        else
            call vimqq#sys_msg#info(a:chat_id, 'Try sending your message after assistant reply is complete')
        endif
        let self._queues[a:chat_id] = queue
        return sent
    endfunction

    function! dispatcher.reply_complete(chat_id) dict
        let sent  = v:false
        let queue = get(self._queues, a:chat_id, [])

        if empty(queue)
            vimqq#log#error('got a reply from non-enqueued query')
            return v:false
        endif

        " Remove completed query
        let [_last_message, _last_bot] = remove(queue, 0)

        let self._queues[a:chat_id] = queue
    endfunction

    return dispatcher
endfunction
