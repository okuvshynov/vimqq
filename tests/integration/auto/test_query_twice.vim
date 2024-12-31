let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! s:verify()
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'query_twice.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

function! AskNew(t)
    :Q @mock world!
    call DELAYED_VERIFY(400, function("s:verify"))
endfunction

:Q @mock hello
call timer_start(400, "AskNew")

