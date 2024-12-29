let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../api_chat_test.vim"
execute "source " . s:lib
let s:libs = s:path . "/../api_chat_test_stream.vim"
execute "source " . s:libs

let llm = vimqq#api#mistral_api#new()
call TestAPIChat(llm, 'mistral-small-latest')
call TestAPIChatStream(llm, 'mistral-small-latest')
