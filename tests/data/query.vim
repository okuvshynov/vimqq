function! WriteAndQuit(t)
    execute "write query.out"
    execute "qa!"
endfunction

:Q @mock hello
call timer_start(100, "WriteAndQuit")
