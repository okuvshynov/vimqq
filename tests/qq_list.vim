function! WriteAndQuit(t)
    :normal q
    execute "write qq_list.out"
    execute "qa!"
endfunction

:put!=range(1,5)
:normal ggV5j
:execute "normal! \<Esc>"
:'<,'>QQ -s @mock hello
call timer_start(1000, "WriteAndQuit")
