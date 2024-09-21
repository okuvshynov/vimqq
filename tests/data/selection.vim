function! WriteAndQuit(t)
    execute "write selection.out"
    execute "qa!"
endfunction

:put!=range(1,5)
:normal ggV5j
:execute "normal! \<Esc>"
:'<,'>QQ -s @mock hello
call timer_start(500, "WriteAndQuit")
