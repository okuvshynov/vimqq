let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../libtest.vim"
execute "source " . s:lib

function! s:test_context()
    let s:message = {'context' : 'CONTEXT', 'message': 'MESSAGE'}

    let s:formatted = vimqq#fmt#content(s:message)

    call ASSERT_EQ("Here's a code snippet: \n\nCONTEXT\n\nMESSAGE", s:formatted)

endfunction

function! s:test_escape()
    let s:message = {'context' : 'CON&TEXT', 'message': 'MESSAGE'}

    let s:formatted = vimqq#fmt#content(s:message)

    call ASSERT_EQ("Here's a code snippet: \n\nCON&TEXT\n\nMESSAGE", s:formatted)

endfunction

function! s:test_no_context()
    let s:message = {'message': 'MESSAGE'}

    let s:formatted = vimqq#fmt#content(s:message)

    call ASSERT_EQ("MESSAGE", s:formatted)
endfunction

call s:test_context()
call s:test_escape()
call s:test_no_context()

cquit 0
