let s:suite = themis#suite('test_controller.vim')
let s:assert = themis#helper('assert')

" E2E logic testing, excluding UI
function s:suite.before()
    :bufdo! bd! | enew
    call delete(g:vqq_chats_dir, 'rf')
    call vimqq#main#setup()
endfunction

function s:suite.test_send_message()
    call vimqq#main#send_message(v:false, "@mqq Hello, world!")
    :sleep 500m
    let filename = g:vqq_chats_dir . '/chat_1.json'
    let chat = json_decode(join(readfile(filename), ''))
    call vimqq#log#info(string(chat))

    " Filter out 'local' messages
    let valid_messages = filter(copy(chat.messages), 'v:val.role == "user" || v:val.role == "assistant"')
    
    " Check we have exactly 2 messages (user and assistant)
    call s:assert.equal(len(valid_messages), 2)
    
    " Assert user message properties
    let user_msg = valid_messages[0]
    call s:assert.equal(user_msg.role, 'user')
    call s:assert.equal(user_msg.bot_name, 'mqq')
    call s:assert.equal(user_msg.sources.text, 'Hello, world!')
    call s:assert.equal(len(user_msg.content), 1)
    call s:assert.equal(user_msg.content[0].type, 'text')
    call s:assert.equal(user_msg.content[0].text, 'Hello, world!')
    
    " Assert assistant message properties
    let assistant_msg = valid_messages[1]
    call s:assert.equal(assistant_msg.role, 'assistant')
    call s:assert.equal(assistant_msg.bot_name, 'mqq')
    call s:assert.equal(len(assistant_msg.content), 1)
    call s:assert.equal(assistant_msg.content[0].type, 'text')
    call s:assert.equal(assistant_msg.content[0].text, 'The conversation length is 41 characters. ')
    
    " Check chat properties
    call s:assert.equal(chat.id, 1)
    call s:assert.true(chat.title_computed)
    call s:assert.equal(chat.title, 'The conversation length is 165 characters.')
endfunction
