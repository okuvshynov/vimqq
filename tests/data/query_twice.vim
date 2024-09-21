function! WriteAndQuit(t)
    execute "write query_twice.out"
    execute "qa!"
endfunction

function! AskNew(t)
    :Q @mock world!
    call timer_start(1000, "WriteAndQuit")
endfunction

:Q @mock hello
call timer_start(1000, "AskNew")

