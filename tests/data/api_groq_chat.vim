let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../api_chat_test.vim"
execute "source " . s:lib
let s:lib = s:path . "/../api_chat_test_stream.vim"
execute "source " . s:lib

let impl = vimqq#api#groq_api#new()

call TestAPIChat(impl, 'llama-3.1-8b-instant')
call TestAPIChatStream(impl, 'llama-3.1-8b-instant')
