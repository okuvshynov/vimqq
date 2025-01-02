let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../libtest.vim"
execute "source " . s:lib

function! Test_context()
    let s:message = {'context' : 'CONTEXT', 'message': 'MESSAGE'}

    let s:formatted = vimqq#fmt#content(s:message)

    call ASSERT_EQ("Here's a code snippet: \n\nCONTEXT\n\nMESSAGE", s:formatted)

endfunction

function! Test_escape()
    let s:message = {'context' : 'CON&TEXT', 'message': 'MESSAGE'}

    let s:formatted = vimqq#fmt#content(s:message)

    call ASSERT_EQ("Here's a code snippet: \n\nCON&TEXT\n\nMESSAGE", s:formatted)

endfunction

function! Test_no_context()
    let s:message = {'message': 'MESSAGE'}

    let s:formatted = vimqq#fmt#content(s:message)

    call ASSERT_EQ("MESSAGE", s:formatted)
endfunction

" This runs all the functions defined with name Test_
call RunAllTests()
