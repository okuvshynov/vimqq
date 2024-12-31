let s:chunks = []
let s:completed = v:false

function! Verify(t)
    call ASSERT_TRUE(s:completed)
    call ASSERT_EQ(len(s:chunks), 1)
    cquit 0
endfunction

function! s:on_chunk(params, chunk)
    echom a:chunk
    call add(s:chunks, a:chunk)
endfunction

function! s:on_complete(params)
    let s:completed = v:true
    call Verify(0)
endfunction

function! TestAPIChat(impl, model='')
    let params = {
        \ 'messages' : [{'role': 'user', 'content': 'What is the capital of Poland?'}],
        \ 'on_chunk' : {p, chunk -> s:on_chunk(p, chunk)},
        \ 'on_complete' : {p -> s:on_complete(p)},
        \ 'model': a:model
    \ }
    call a:impl.chat(params)
    call timer_start(10000, 'Verify')
endfunction
