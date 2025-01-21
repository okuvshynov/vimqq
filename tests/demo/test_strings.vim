let s:suite = themis#suite('demo_strings')
let s:assert = themis#helper('assert')

function s:suite.test_basic()
    let content = "hello, world!"
    let needle = "hello"
    let replacement = "Hello"
    let expected = "Hello, world!"

    let observed = substitute(content, needle, replacement, '')

    call s:assert.equals(observed, expected)
endfunction

function s:suite.test_newline()
    let content = "hello\nworld!"
    let needle = "hello"
    let replacement = "Hello"
    let expected = "Hello\nworld!"

    let observed = substitute(content, needle, replacement, '')

    call s:assert.equals(observed, expected)
endfunction


" This one is counter-intuitive to me
function s:suite.test_newline_sub_split()
    let content = "hello, world!"
    let needle = "hello, "
    let replacement = "Hello\n"

    let observed = substitute(content, needle, replacement, '')
    let lines = split(observed, '\n', 1)

    call s:assert.equals(len(lines), 2)
endfunction

function s:suite.test_newline_split0()
    let content = "hello\nworld!"
    let lines = split(content, '\n', 1)

    call s:assert.equals(len(lines), 2)
endfunction

function s:suite.test_newline_split1()
    let content = 'hello\nworld!'
    let lines = split(content, '\n', 1)

    call s:assert.equals(len(lines), 1)
endfunction

function s:suite.test_newline_split2()
    let content = 'hello\nworld!'
    let lines = split(content, "\n", 1)

    call s:assert.equals(len(lines), 1)
endfunction

function s:suite.test_newline_split3()
    let content = "hello\nworld!"
    let lines = split(content, "\n", 1)

    call s:assert.equals(len(lines), 2)
endfunction

function s:suite.test_newline_sub()
    let content = "hello, world!"
    let lines = split(content, "\n", 1)

    call s:assert.equals(len(lines), 1)
endfunction
