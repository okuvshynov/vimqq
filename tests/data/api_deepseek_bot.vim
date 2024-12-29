let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../bot_test.vim"
execute "source " . s:lib

let impl = vimqq#api#deepseek_api#new()

let s:client = vimqq#client#new(impl, {'model': 'deepseek-chat'})

call VQQBotTest(s:client)
