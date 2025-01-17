let s:suite = themis#suite('api')
let s:assert = themis#helper('assert')

function s:run_chat_test(impl, model, stream = v:false)
    :bufdo! bd! | enew
    call delete(g:vqq_chats_file)
    call vimqq#main#setup()
    let chunks = []
    let done = v:false
    function! OnChunk(params, chunk) closure
        call add(chunks, a:chunk)
    endfunction

    function! OnComplete(params) closure
        let done = v:true
    endfunction

    let params = {
        \ 'messages' : [{'role': 'user', 'content': 'What is the capital of Poland?'}],
        \ 'on_chunk' : {p, chunk -> OnChunk(p, chunk)},
        \ 'on_complete' : {p -> OnComplete(p)},
        \ 'model': a:model
    \ }

    if a:stream == v:true
        let params['stream'] = v:true
    endif
    call a:impl.chat(params)
    for i in range(20)
        if done
            break
        endif
        :sleep 500m
    endfor
    call s:assert.equals(done, v:true)
    if a:stream
        call s:assert.compare(len(chunks), '>', 1)
    else
        call s:assert.equals(len(chunks), 1)
    endif
endfunction

function s:suite.test_anthropic()
    let impl = vimqq#api#anthropic_api#new()
    let model = 'claude-3-5-haiku-latest'
    call s:run_chat_test(impl, model)
endfunction

function s:suite.test_anthropic_stream()
    let impl = vimqq#api#anthropic_api#new()
    let model = 'claude-3-5-haiku-latest'
    call s:run_chat_test(impl, model, v:true)
endfunction

function s:suite.test_deepseek()
    let impl = vimqq#api#deepseek_api#new()
    let model = 'deepseek-chat'
    call s:run_chat_test(impl, model)
endfunction

function s:suite.test_deepseek_stream()
    let impl = vimqq#api#deepseek_api#new()
    let model = 'deepseek-chat'
    call s:run_chat_test(impl, model, v:true)
endfunction

function s:suite.test_groq()
    let impl = vimqq#api#groq_api#new()
    let model = 'llama-3.1-8b-instant'
    call s:run_chat_test(impl, model)
endfunction

function s:suite.test_groq_stream()
    let impl = vimqq#api#groq_api#new()
    let model = 'llama-3.1-8b-instant'
    call s:run_chat_test(impl, model, v:true)
endfunction

function s:suite.test_llama_cpp()
    let impl = vimqq#api#llama_api#new('http://localhost:8080/v1/chat/completions')
    let model = ''
    call s:run_chat_test(impl, model)
endfunction

function s:suite.test_llama_cpp_stream()
    let impl = vimqq#api#llama_api#new('http://localhost:8080/v1/chat/completions')
    let model = ''
    call s:run_chat_test(impl, model, v:true)
endfunction

function s:suite.test_mistral()
    let impl = vimqq#api#mistral_api#new()
    let model = 'mistral-small-latest'
    call s:run_chat_test(impl, model)
endfunction

function s:suite.test_mistral_stream()
    let impl = vimqq#api#mistral_api#new()
    let model = 'mistral-small-latest'
    call s:run_chat_test(impl, model, v:true)
endfunction

