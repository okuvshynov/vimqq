let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

function! WriteAndQuit(t)
    " go to list
    :QQList
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'chat_list_one.out')
    if VQQCompareChats(content, expected) == 0
        cquit 0
    else
        cquit 1
    endif
endfunction

:put!=range(1,5)
:normal ggV5j
:execute "normal! \<Esc>"
:'<,'>QQ @mock hello
call timer_start(500, "WriteAndQuit")
