let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! Test_query_twice()
    :QQ @mock hello
    :sleep 500m
    :QQ @mock world!
    :sleep 500m

    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'query_twice.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

call RunAllTests()
