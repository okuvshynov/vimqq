let s:suite = themis#suite('Prompt formatting')
let s:assert = themis#helper('assert')

function s:suite.test_context()
    let l:message = {'sources': {'context' : 'CONTEXT', 'text': 'MESSAGE'}}
    let l:formatted = vimqq#fmt#content(l:message)
    let l:expected = "Here's a code snippet:\n\nCONTEXT\n\nMESSAGE"
    call s:assert.equals(l:formatted, l:expected)
endfunction

function s:suite.test_context_escape()
    let l:message = {'sources': {'context' : 'CON&TEXT', 'text': 'MESSAGE'}}
    let l:formatted = vimqq#fmt#content(l:message)
    let l:expected = "Here's a code snippet:\n\nCON&TEXT\n\nMESSAGE"
    call s:assert.equals(l:formatted, l:expected)
endfunction

function s:suite.test_no_context()
    let l:message = {'sources': {'text': 'MESSAGE'}}
    let l:formatted = vimqq#fmt#content(l:message)
    let l:expected = "MESSAGE"
    call s:assert.equals(l:formatted, l:expected)
endfunction
