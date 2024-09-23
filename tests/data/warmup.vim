let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../libtest.vim"
execute "source " . s:lib

function! WriteAndQuit(t)
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'query.out')
    if VQQCompareChats(content, expected) == 0
        cquit 0
    else
        cquit 1
    endif
endfunction

:Q -w @mock hello
:Q @mock hello
call timer_start(100, "WriteAndQuit")
