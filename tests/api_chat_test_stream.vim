let s:chunks = []
let s:completed = v:false

function! VerifyStream(t)
    call ASSERT_TRUE(s:completed)
    call ASSERT_GT(len(s:chunks), 1)
    cquit 0
endfunction

function! s:on_chunk(params, chunk)
    echom a:chunk
    call add(s:chunks, a:chunk)
endfunction

function! s:on_complete(params)
    let s:completed = v:true
    call VerifyStream(0)
endfunction

function! TestAPIChatStream(impl, model='')
    let params = {
        \ 'messages' : [{'role': 'user', 'content': 'What is the capital of Poland?'}],
        \ 'on_chunk' : {p, chunk -> s:on_chunk(p, chunk)},
        \ 'on_complete' : {p -> s:on_complete(p)},
        \ 'stream' : v:true,
        \ 'model': a:model
    \ }
    call a:impl.chat(params)
    call timer_start(10000, 'VerifyStream')
endfunction
