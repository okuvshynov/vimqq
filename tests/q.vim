function! WriteAndQuit(t)
    execute "write q.out"
    execute "qa!"
endfunction
:Q @mock hello
call timer_start(1000, "WriteAndQuit")

