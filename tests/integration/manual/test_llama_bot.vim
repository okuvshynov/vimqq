let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../bot_test.vim"
execute "source " . s:lib

let impl = vimqq#api#llama_api#new('http://localhost:8080/v1/chat/completions')

"let s:client = vimqq#client#new(impl, {'send_warmup': v:true})
let s:client = vimqq#client#new(impl)

call VQQBotTest(s:client)
