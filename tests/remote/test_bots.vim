let s:suite = themis#suite('Real API bot tests')
let s:assert = themis#helper('assert')

function s:run_bot_test(client, expected_events = ['chunk_done', 'reply_done', 'title_done'])
    :bufdo! bd! | enew
    call delete(g:vqq_chats_file)
    call vimqq#main#setup()
    let observer = {}
    let client = a:client
    let events = []

    let message = {
        \ 'sources': {'text' : 'What is the capital of poland?'},
        \ 'role' : 'user'
    \ }

    let done = v:false

    function! observer.handle_event(event, args) closure
        " TODO: This seems wrong!!
        if done
            return
        endif
        call add(events, a:event)
        if a:event == 'reply_done'
            call client.send_gen_title(1, message)
        endif
        if a:event == 'title_done'
            let done = v:true
        endif
    endfunction

    call vimqq#events#set_state({})
    call vimqq#events#add_observer(observer)

    let chat = {'id': 1, 'messages': [message]}
    call client.send_warmup([message])
    call client.send_chat(chat, v:false)
    for i in range(20)
        if done
            break
        endif
        :sleep 500m
    endfor
    call s:assert.equals(done, v:true)
    call s:assert.equals(events, a:expected_events)
endfunction

function s:suite.test_anthropic()
    let impl = vimqq#api#anthropic_api#new()
    let client = vimqq#client#new(impl, {'model': 'claude-3-5-haiku-latest'})
    call s:run_bot_test(client)
endfunction

function s:suite.test_deepseek()
    let impl = vimqq#api#deepseek_api#new()
    let client = vimqq#client#new(impl, {'model': 'deepseek-chat'})
    call s:run_bot_test(client)
endfunction

function s:suite.test_groq()
    let impl = vimqq#api#groq_api#new()
    let client = vimqq#client#new(impl, {'model': 'llama-3.1-8b-instant'})
    call s:run_bot_test(client)
endfunction

function s:suite.test_llama()
    let impl = vimqq#api#llama_api#new('http://localhost:8080/v1/chat/completions')

    "let client = vimqq#client#new(impl, {'send_warmup': v:true})
    let client = vimqq#client#new(impl)
    call s:run_bot_test(client)
endfunction

function s:suite.test_llama_warmup()
    let impl = vimqq#api#llama_api#new('http://localhost:8080/v1/chat/completions')

    let client = vimqq#client#new(impl, {'send_warmup': v:true})
    call s:run_bot_test(client, ['warmup_done', 'chunk_done', 'reply_done', 'title_done'])
endfunction

function s:suite.test_mistral()
    let impl = vimqq#api#mistral_api#new()
    let client = vimqq#client#new(impl, {'model': 'mistral-small-latest'})
    call s:run_bot_test(client)
endfunction
