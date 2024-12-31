let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! s:verify()
    :QQList
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'new_chat.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

function! AskNew(t)
    :QN @mock world!
    call DELAYED_VERIFY(500, function("s:verify"))
endfunction

:Q @mock hello
call timer_start(500, "AskNew")

