function! WriteAndQuit(t)
    :normal q
    execute "write new_chat.out"
    execute "qa!"
endfunction

function! AskNew(t)
    :Q -n @mock world!
    call timer_start(500, "WriteAndQuit")
endfunction

:Q @mock hello
call timer_start(500, "AskNew")

