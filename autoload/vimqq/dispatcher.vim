if exists('g:autoloaded_vimqq_dispatcher')
    finish
endif

let g:autoloaded_vimqq_dispatcher = 1

function! vimqq#dispatcher#new(db) abort
    let l:dispatcher = {}
    
    let l:dispatcher._db = a:db
    let l:dispatcher._queues = {}

    " returns total size of all queues
    function! l:dispatcher.queue_size() dict
        let l:size = 0
        for l:queue in values(self._queues)
          let l:size += len(l:queue)
        endfor
        return l:size
    endfunction 

    " returns
    "   - v:true if query started running immediately
    "   - v:false if query was enqueued
    function! l:dispatcher.enqueue_query(chat_id, bot, message) dict
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

    " Called when a reply to a query is complete.
    " Returns true if there was a queued query started 
    function! l:dispatcher.reply_complete(chat_id) dict
        let l:sent  = v:false
        let l:queue = get(self._queues, a:chat_id, [])

        if empty(l:queue)
            vimqq#log#error('got a reply from non-enqueued query')
            return v:false
        endif

        " Remove completed query
        let [l:last_message, l:last_bot] = remove(l:queue, 0)

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
        return [l:sent, l:last_bot.name()]
    endfunction

    return l:dispatcher
endfunction