let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../api_chat_test.vim"
execute "source " . s:lib
let s:lib = s:path . "/../api_chat_test_stream.vim"
execute "source " . s:lib

let llm = vimqq#api#anthropic_api#new()

call TestAPIChat(llm, 'claude-3-5-haiku-latest')
call TestAPIChatStream(llm, 'claude-3-5-haiku-latest')
