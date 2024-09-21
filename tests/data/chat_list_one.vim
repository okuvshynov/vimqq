function! WriteAndQuit(t)
    :normal q
    execute "write chat_list_one.out"
    execute "qa!"
endfunction

:put!=range(1,5)
:normal ggV5j
:execute "normal! \<Esc>"
:'<,'>QQ -s @mock hello
call timer_start(1000, "WriteAndQuit")
