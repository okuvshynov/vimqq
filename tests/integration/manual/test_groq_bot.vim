let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../bot_test.vim"
execute "source " . s:lib

let impl = vimqq#api#groq_api#new()

let s:client = vimqq#client#new(impl, {'model': 'llama-3.1-8b-instant'})
call VQQBotTest(s:client)
