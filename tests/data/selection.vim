let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../libtest.vim"
execute "source " . s:lib

function! WriteAndQuit(t)
    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'selection.out')
    if VQQCompareChats(content, expected) == 0
        cquit 0
    else
        cquit 1
    endif
endfunction

:put!=range(1,5)
:normal ggV5j
:execute "normal! \<Esc>"
:'<,'>QQ -s @mock hello
call timer_start(100, "WriteAndQuit")
