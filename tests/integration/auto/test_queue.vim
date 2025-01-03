let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! s:verify()
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'queue.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

:Q @mock hello
:Q @mock world!
call DELAYED_VERIFY(1000, function("s:verify"))

