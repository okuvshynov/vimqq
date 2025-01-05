let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! Test_new_chat_nodelay()
    :QQ @mock hello
    :QQN @mock world!
    :sleep 1000m
    :QQList

    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'new_chat_nodelay.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

call RunAllTests()
