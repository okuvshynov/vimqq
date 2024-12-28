let s:chunks = []
let s:completed = v:false

function! s:on_chunk(params, chunk)
    echom a:chunk
    call add(s:chunks, a:chunk)
endfunction

function! s:on_complete(params)
    let s:completed = v:true
endfunction

let llm = vimqq#api#anthropic_api#new()

let params = {
    \ 'messages' : [{'role': 'user', 'content': 'What is the capital of Poland?'}],
    \ 'on_chunk' : {p, chunk -> s:on_chunk(p, chunk)},
    \ 'on_complete' : {p -> s:on_complete(p)},
    \ 'model': 'claude-3-5-haiku-latest',
\ }

call llm.chat(params)

function! Verify(t)
    if !s:completed
        cquit 1
    endif
    if len(s:chunks) != 1
        cquit 1
    endif
    cquit 0
endfunction

call timer_start(10000, 'Verify')
