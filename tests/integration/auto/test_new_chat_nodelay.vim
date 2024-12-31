let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! s:verify()
    :QQList

    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'new_chat_nodelay.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

:Q @mock hello
:QN @mock world!
call DELAYED_VERIFY(1000, function("s:verify"))

