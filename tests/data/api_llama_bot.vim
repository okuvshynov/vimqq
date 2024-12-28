let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../libtest.vim"
execute "source " . s:lib

let impl = vimqq#api#llama_api#new('http://localhost:8080/v1/chat/completions')

let s:client = vimqq#client#new(impl, {'send_warmup': v:true})

let s:message = {
    \ 'message' : 'What is the capital of poland?',
    \ 'role' : 'user'
\ }

let s:observer = {}
let s:events = []
function! s:observer.handle_event(event, args)
    call add(s:events, a:event)
    if a:event == 'warmup_done'
        call s:client.send_chat(1, [s:message])
    endif
    if a:event == 'reply_done'
        call s:client.send_gen_title(1, s:message)
    endif
endfunction

call vimqq#model#set_state({})
call vimqq#model#add_observer(s:observer)

call s:client.send_warmup([s:message])

function! Verify(t)
    echom s:events
    let expected = ['warmup_done', 'chunk_done', 'reply_done', 'title_done']
    if ArrayCompare(expected, s:events) == 0
        cquit 0
    else
        cquit 1
    endif
endfunction

call timer_start(10000, 'Verify')
