let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../api_chat_test.vim"
execute "source " . s:lib
let s:lib = s:path . "/../../api_chat_test_stream.vim"
execute "source " . s:lib

let llm = vimqq#api#llama_api#new('http://localhost:8080/v1/chat/completions')

call TestAPIChat(llm)
call TestAPIChatStream(llm)

