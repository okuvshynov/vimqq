let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../bot_test.vim"
execute "source " . s:lib

let impl = vimqq#api#anthropic_api#new()

let s:client = vimqq#client#new(impl, {'model': 'claude-3-5-haiku-latest'})

call VQQBotTest(s:client)
