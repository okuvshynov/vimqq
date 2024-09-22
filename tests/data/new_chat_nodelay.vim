function! WriteAndQuit(t)
    :normal q
    execute "write new_chat_nodelay.out"
    execute "qa!"
endfunction

:Q @mock hello
:Q -n @mock world!
call timer_start(500, "WriteAndQuit")

