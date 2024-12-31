let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

:put!=range(1,5)
:normal ggV5j
:execute "normal! \<Esc>"
:'<,'>QQ @mock hello

function! s:verify()
    " go to list
    :QQList
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'chat_list_one.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

call DELAYED_VERIFY(500, function('s:verify'))
