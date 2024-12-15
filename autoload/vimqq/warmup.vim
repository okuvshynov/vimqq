if exists('g:autoloaded_vimqq_warmup')
    finish
endif

let g:autoloaded_vimqq_warmup = 1

function! vimqq#warmup#new(bots, db) abort
    let l:w = {}
    let l:w._bots = []
    let l:w._db = a:db
    for bot in a:bots.bots()
        if bot.do_autowarm()
            call add(l:w._bots, bot)
        endif
    endfor

    function! l:w.handle_event(event, args) dict
        if a:event == 'title_saved' || a:event == 'chat_opened'

            let chat_id = a:args['chat_id']
            if !self._db.chat_exists(chat_id)
                call vimqq#log#info("warmup on non-existent chat.")
                return
            endif
            let messages = self._db.get_messages(chat_id)
            for bot in self._bots
                call vimqq#metrics#inc(bot.name() . ".chat_warmups" )
                call bot.send_warmup(messages)
            endfor
        endif
    endfunction

    return l:w
endfunction

