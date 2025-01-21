let s:suite = themis#suite('str_replace')
let s:assert = themis#helper('assert')

function s:suite.test_basic()
    let observed = vimqq#str#replace("hello, world", "hello", "Hello")
    call s:assert.equals(observed, "Hello, world")
endfunction

function s:suite.test_unicode()
    let observed = vimqq#str#replace("▄hello, world", "hello", "Hello")
    call s:assert.equals(observed, "▄Hello, world")
endfunction

function s:suite.test_unicode_from()
    let observed = vimqq#str#replace("▄hello▂, world", "hello▂", "Hello")
    call s:assert.equals(observed, "▄Hello, world")
endfunction

function s:suite.test_no_magic()
    let observed = vimqq#str#replace("hello~world", "hello~", "Hello~, ")
    call s:assert.equals(observed, "Hello~, world")
endfunction

function s:suite.test_nl0()
    let observed = vimqq#str#replace("hello\nworld", "hello", "Hello")
    call s:assert.equals(observed, "Hello\nworld")
endfunction

function s:suite.test_nl1()
    let observed = vimqq#str#replace('hello\nworld', "hello", "Hello")
    call s:assert.equals(observed, 'Hello\nworld')
endfunction

function s:suite.test_nl2()
    let observed = vimqq#str#replace('hello\nworld', 'hello\n', 'Hello, ')
    call s:assert.equals(observed, 'Hello, world')
endfunction

function s:suite.test_nl3()
    let observed = vimqq#str#replace("hello\nworld", "hello\n", "Hello, ")
    call s:assert.equals(observed, "Hello, world")
endfunction

