let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../api_chat_test.vim"
execute "source " . s:lib
let s:lib = s:path . "/../../api_chat_test_stream.vim"
execute "source " . s:lib

let llm = vimqq#api#deepseek_api#new()

call TestAPIChat(llm, 'deepseek-chat')
call TestAPIChatStream(llm, 'deepseek-chat')
