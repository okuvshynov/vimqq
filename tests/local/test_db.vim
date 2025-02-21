let s:suite = themis#suite('test_db.vim')
let s:assert = themis#helper('assert')

let s:test_db_file = tempname()

function s:suite.before_each()
    call delete(s:test_db_file)
endfunction

function s:suite.test_new_db()
    let db = vimqq#db#new(s:test_db_file)
    call s:assert.equals(type(db), v:t_dict)
    call s:assert.equals(db._seq_id, 0)
    call s:assert.equals(len(db._chats), 0)
endfunction

function s:suite.test_new_chat()
    let db = vimqq#db#new(s:test_db_file)
    let chat_id = db.new_chat()
    call s:assert.true(db.chat_exists(chat_id))
    let chat = db.get_chat(chat_id)
    call s:assert.equals(chat.title, 'new chat')
    call s:assert.false(chat.title_computed)
    call s:assert.equals(len(chat.messages), 0)
endfunction

function s:suite.test_append_message()
    let db = vimqq#db#new(s:test_db_file)
    let chat_id = db.new_chat()
    let message = {'role': 'user', 'sources': {'text': 'test message'}}
    call db.append_message(chat_id, message)
    let messages = db.get_messages(chat_id)
    call s:assert.equals(len(messages), 1)
    call s:assert.equals(messages[0].role, 'user')
    call s:assert.equals(messages[0].sources.text, 'test message')
    call s:assert.true(has_key(messages[0], 'timestamp'))
    call s:assert.true(has_key(messages[0], 'seq_id'))
endfunction

function s:suite.test_title_management()
    let db = vimqq#db#new(s:test_db_file)
    let chat_id = db.new_chat()
    call s:assert.false(db.has_title(chat_id))
    call db.set_title(chat_id, 'Test Title')
    call s:assert.true(db.has_title(chat_id))
    call s:assert.equals(db.get_title(chat_id), 'Test Title')
endfunction

function s:suite.test_partial_message()
    let db = vimqq#db#new(s:test_db_file)
    let chat_id = db.new_chat()
    let bot_name = 'test_bot'
    
    " Test reset and get partial
    call db.reset_partial(chat_id, bot_name)
    let partial = db.get_partial(chat_id)
    call s:assert.equals(partial.role, 'assistant')
    call s:assert.equals(partial.bot_name, bot_name)
    call s:assert.equals(partial.sources.text, '')
    
    " Test append partial
    call db.append_partial(chat_id, 'hello')
    call db.append_partial(chat_id, ' world')
    let partial = db.get_partial(chat_id)
    call s:assert.equals(partial.sources.text, 'hello world')
    
    " Test partial done
    call db.partial_done(chat_id)
    let messages = db.get_messages(chat_id)
    call s:assert.equals(len(messages), 1)
    call s:assert.equals(messages[0].sources.text, 'hello world')
    
    " Check partial was cleared
    let new_partial = db.get_partial(chat_id)
    call s:assert.equals(new_partial.sources.text, '')
endfunction

function s:suite.test_persistence()
    " Create and populate database
    let db = vimqq#db#new(s:test_db_file)
    let chat_id = db.new_chat()
    let message = {'role': 'user', 'sources': {'text': 'test message'}}
    call db.append_message(chat_id, message)
    call db.set_title(chat_id, 'Test Title')
    
    " Create new instance and verify data persisted
    let db2 = vimqq#db#new(s:test_db_file)
    call s:assert.true(db2.chat_exists(chat_id))
    call s:assert.equals(db2.get_title(chat_id), 'Test Title')
    let messages = db2.get_messages(chat_id)
    call s:assert.equals(len(messages), 1)
    call s:assert.equals(messages[0].sources.text, 'test message')
endfunction

function s:suite.test_chat_list_ordering()
    let db = vimqq#db#new(s:test_db_file)
    
    " Create chats in specific order
    let chat_id1 = db.new_chat()
    call db.set_title(chat_id1, 'First Chat')
    let chat_id2 = db.new_chat()
    call db.set_title(chat_id2, 'Second Chat')
    
    " Add message to first chat to make it more recent
    let message = {'role': 'user', 'sources': {'text': 'test message'}}
    call db.append_message(chat_id1, message)
    
    " Get ordered chats and verify order
    let chats = db.get_ordered_chats()
    call s:assert.equals(len(chats), 2)
    call s:assert.equals(chats[0].id, chat_id1)  " Most recent first
    call s:assert.equals(chats[1].id, chat_id2)
endfunction

function s:suite.test_delete_chat()
    let db = vimqq#db#new(s:test_db_file)
    let chat_id = db.new_chat()
    call s:assert.true(db.chat_exists(chat_id))
    call db.delete_chat(chat_id)
    call s:assert.false(db.chat_exists(chat_id))
endfunction
