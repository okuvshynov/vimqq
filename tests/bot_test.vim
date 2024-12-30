let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/libtest.vim"
execute "source " . s:lib

let s:observer = {}
let s:events = []
let s:expected = ['chunk_done', 'reply_done', 'title_done']

function! Verify(t)
    if ArrayCompare(s:expected, s:events) == 0
        cquit 0
    else
        cquit 1
    endif
endfunction

function! s:observer.handle_event(event, args)
    call add(s:events, a:event)
    if a:event == 'reply_done'
        call s:client.send_gen_title(1, s:message)
    endif
    if a:event == 'title_done'
        call Verify(0)
    endif
endfunction

function! VQQBotTest(client)

    let s:message = {
        \ 'message' : 'What is the capital of poland?',
        \ 'role' : 'user'
    \ }

    let s:client = a:client

    call vimqq#events#set_state({})
    call vimqq#events#add_observer(s:observer)

    call s:client.send_warmup([s:message])
    call s:client.send_chat(1, [s:message], v:false)

    call timer_start(10000, 'Verify')
endfunction
