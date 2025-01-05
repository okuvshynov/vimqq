let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! Test_chat_list_one()
    " 5 lines with 1, 2, 3, 4, 5
    :put!=range(1,5)
    " visual select them
    :normal ggV5j
    " Call mock bot with the selection
    :execute "normal! \<Esc>"
    :'<,'>QQ @mock hello

    " sleep to get the reply
    :sleep 1

    " go to list
    :QQList
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'chat_list_one.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

call RunAllTests()
