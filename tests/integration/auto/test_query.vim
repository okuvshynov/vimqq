let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! Test_query()
    :QQ @mock hello
    :sleep 500m
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'query.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

call RunAllTests()
