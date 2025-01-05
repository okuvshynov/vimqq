let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! Test_selection()
    :put!=range(1,5)
    :normal ggV5j
    :execute "normal! \<Esc>"
    :'<,'>QQ @mock hello
    :sleep 500m

    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'selection.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

call RunAllTests()
