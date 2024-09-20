function! WriteAndQuit(t)
    execute "write history.txt"
    execute "qa!"
endfunction
:Q @mock hello
call timer_start(5000, "WriteAndQuit")

