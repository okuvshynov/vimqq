let s:suite = themis#suite('test_controller.vim')
let s:assert = themis#helper('assert')

" E2E logic testing, excluding UI
function s:suite.before_each()
    :bufdo! bd! | enew!
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

function s:suite.test_force_new_chat()
    " Send a first message to create chat ID 1
    call vimqq#main#send_message(v:false, "@mqq First message")
    :sleep 500m
    
    " Check that the chat was created with ID 1
    let filename = g:vqq_chats_dir . '/chat_1.json'
    let chat = json_decode(join(readfile(filename), ''))
    call s:assert.equal(chat.id, 1)
    
    " Send a second message without force_new_chat - should go to chat ID 1
    call vimqq#main#send_message(v:false, "@mqq Second message")
    :sleep 500m

    " Send a third message with force_new_chat=v:true - should create chat ID 2
    call vimqq#main#send_message(v:true, "@mqq Third message")
    :sleep 500m
    
    " Check that chat ID 1 now has two user messages
    let chat = json_decode(join(readfile(filename), ''))
    let user_messages = filter(copy(chat.messages), 'v:val.role == "user"')
    call s:assert.equal(len(user_messages), 2)
    call s:assert.equal(user_messages[0].sources.text, 'First message')
    call s:assert.equal(user_messages[1].sources.text, 'Second message')
    
    " Find the new chat file (should be the newest chat file with ID > 1)
    let chat_files = glob(g:vqq_chats_dir . '/chat_*.json', 0, 1)
    let new_chat_files = filter(copy(chat_files), 'v:val !~ "/chat_1\\.json$"')
    call s:assert.equal(len(new_chat_files), 1)
    
    " Use the first found new chat file
    let filename2 = new_chat_files[0]
    let chat2 = json_decode(join(readfile(filename2), ''))
    
    " Check that the new chat has only one user message
    let user_messages = filter(copy(chat2.messages), 'v:val.role == "user"')
    call s:assert.equal(len(user_messages), 1)
    call s:assert.equal(user_messages[0].sources.text, 'Third message')
endfunction
