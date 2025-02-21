let s:suite = themis#suite('test_fmt.vim')
let s:assert = themis#helper('assert')

function s:suite.test_content_with_prompt()
    let l:message = {'sources': {'context' : 'CONTEXT', 'text': 'MESSAGE'}}
    let l:formatted = vimqq#prompts#apply(l:message, "Here's a code snippet:\n\n{vqq_context}\n\n{vqq_message}")
    let l:expected = "Here's a code snippet:\n\nCONTEXT\n\nMESSAGE"
    call s:assert.equals(l:formatted, l:expected)
endfunction

function s:suite.test_content_escape()
    let l:message = {'sources': {'context' : 'CON&TEXT', 'text': 'MESSAGE'}}
    let l:formatted = vimqq#prompts#apply(l:message, "Here's a code snippet:\n\n{vqq_context}\n\n{vqq_message}")
    let l:expected = "Here's a code snippet:\n\nCON&TEXT\n\nMESSAGE"
    call s:assert.equals(l:formatted, l:expected)
endfunction

function s:suite.test_content_no_context()
    let l:message = {'sources': {'text': 'MESSAGE'}}
    let l:formatted = vimqq#prompts#apply(l:message, "{vqq_message}")
    let l:expected = "MESSAGE"
    call s:assert.equals(l:formatted, l:expected)
endfunction
