function! WriteAndQuit(t)
    execute "write queue.out"
    execute "qa!"
endfunction

:Q @mock hello
:Q @mock world!
call timer_start(200, "WriteAndQuit")

