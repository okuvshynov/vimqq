let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! Test_new_chat()
    :QQ @mock hello
    :sleep 500m
    :QQN @mock world!
    :sleep 500m
    :QQList
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'new_chat.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

call RunAllTests()
