let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! WriteAndQuit(t)
    :QQList
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'new_chat.out')
    if VQQCompareChats(content, expected) == 0
        cquit 0
    else
        cquit 1
    endif
endfunction

function! AskNew(t)
    :QN @mock world!
    call timer_start(500, "WriteAndQuit")
endfunction

:Q @mock hello
call timer_start(500, "AskNew")

