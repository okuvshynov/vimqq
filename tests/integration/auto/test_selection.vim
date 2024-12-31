let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! s:verify()
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'selection.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

:put!=range(1,5)
:normal ggV5j
:execute "normal! \<Esc>"
:'<,'>QQ @mock hello
call DELAYED_VERIFY(200, function("s:verify"))
