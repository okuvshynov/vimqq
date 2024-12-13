let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../libtest.vim"
execute "source " . s:lib

function! WriteAndQuit(t)
    :QQList

    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'new_chat_nodelay.out')
    if VQQCompareChats(content, expected) == 0
        cquit 0
    else
        cquit 1
    endif
endfunction

:Q @mock hello
:Q -n @mock world!
call timer_start(1000, "WriteAndQuit")

