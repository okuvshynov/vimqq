let s:suite = themis#suite('test_usage.vim')
let s:assert = themis#helper('assert')

function s:suite.test_new_usage()
    let usage = vimqq#usage#new()
    call s:assert.equals(type(usage), v:t_dict)
    call s:assert.equals(type(usage.by_chat), v:t_dict)
    call s:assert.equals(len(usage.by_chat), 0)
endfunction

function s:suite.test_merge_new_chat()
    let usage = vimqq#usage#new()
    let chat_id = 'chat1'
    let bot_name = 'test_bot'
    let usage_data = {'input_tokens': 100, 'output_tokens': 50}
    
    call usage.merge(chat_id, bot_name, usage_data)
    
    " Verify chat_id was added
    call s:assert.true(has_key(usage.by_chat, chat_id))
    
    " Verify bot_name was added under chat_id
    let chat_data = usage.by_chat[chat_id]
    call s:assert.true(has_key(chat_data, bot_name))
    
    " Verify usage data was stored correctly
    let bot_data = chat_data[bot_name]
    call s:assert.equals(bot_data.input_tokens, 100)
    call s:assert.equals(bot_data.output_tokens, 50)
endfunction

function s:suite.test_merge_existing_data()
    let usage = vimqq#usage#new()
    let chat_id = 'chat1'
    let bot_name = 'test_bot'
    
    " Add initial usage data
    call usage.merge(chat_id, bot_name, {'input_tokens': 100, 'output_tokens': 50})
    
    " Add more usage data for the same chat and bot
    call usage.merge(chat_id, bot_name, {'input_tokens': 50, 'output_tokens': 25})
    
    " Verify data was merged (sums of values)
    let bot_data = usage.by_chat[chat_id][bot_name]
    call s:assert.equals(bot_data.input_tokens, 150)
    call s:assert.equals(bot_data.output_tokens, 75)
endfunction

function s:suite.test_merge_different_metrics()
    let usage = vimqq#usage#new()
    let chat_id = 'chat1'
    let bot_name = 'test_bot'
    
    " Add initial usage data with one metric
    call usage.merge(chat_id, bot_name, {'input_tokens': 100})
    
    " Add more usage data with a different metric
    call usage.merge(chat_id, bot_name, {'output_tokens': 50})
    
    " Verify both metrics are present
    let bot_data = usage.by_chat[chat_id][bot_name]
    call s:assert.equals(bot_data.input_tokens, 100)
    call s:assert.equals(bot_data.output_tokens, 50)
endfunction

function s:suite.test_multiple_bots()
    let usage = vimqq#usage#new()
    let chat_id = 'chat1'
    
    " Add usage for first bot
    call usage.merge(chat_id, 'bot1', {'input_tokens': 100})
    
    " Add usage for second bot
    call usage.merge(chat_id, 'bot2', {'output_tokens': 50})
    
    " Verify data for both bots is stored correctly
    let chat_data = usage.by_chat[chat_id]
    call s:assert.equals(chat_data.bot1.input_tokens, 100)
    call s:assert.equals(chat_data.bot2.output_tokens, 50)
endfunction

function s:suite.test_multiple_chats()
    let usage = vimqq#usage#new()
    
    " Add usage for first chat
    call usage.merge('chat1', 'bot1', {'input_tokens': 100})
    
    " Add usage for second chat
    call usage.merge('chat2', 'bot1', {'output_tokens': 50})
    
    " Verify data for both chats is stored correctly
    call s:assert.equals(usage.by_chat.chat1.bot1.input_tokens, 100)
    call s:assert.equals(usage.by_chat.chat2.bot1.output_tokens, 50)
endfunction

function s:suite.test_get_nonexistent_chat()
    let usage = vimqq#usage#new()
    
    " Try to get data for a chat that doesn't exist
    let result = usage.get('nonexistent')
    
    " Should return an empty dictionary
    call s:assert.equals(type(result), v:t_dict)
    call s:assert.equals(len(result), 0)
endfunction

function s:suite.test_get_chat_usage()
    let usage = vimqq#usage#new()
    let chat_id = 'chat1'
    
    " Add usage for multiple bots in the same chat
    call usage.merge(chat_id, 'bot1', {'input_tokens': 100})
    call usage.merge(chat_id, 'bot2', {'output_tokens': 50})
    
    " Get the usage data for the chat
    let chat_usage = usage.get(chat_id)
    
    " Verify the returned data is correct
    call s:assert.equals(type(chat_usage), v:t_dict)
    call s:assert.equals(len(chat_usage), 2)
    call s:assert.true(has_key(chat_usage, 'bot1'))
    call s:assert.true(has_key(chat_usage, 'bot2'))
    call s:assert.equals(chat_usage.bot1.input_tokens, 100)
    call s:assert.equals(chat_usage.bot2.output_tokens, 50)
endfunction