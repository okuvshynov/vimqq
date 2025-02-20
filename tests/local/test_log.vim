let s:suite = themis#suite('test_log.vim')
let s:assert = themis#helper('assert')

" NOTE: In this file line numbers matter, as we test logger ability to
" identify those.

function! VQQTestLogCallsite0()
    call vimqq#log#info('hello, world')
endfunction

function s:suite.before_each()
    call delete(g:vqq_log_file)
endfunction

function s:suite.test_fn_call()
    call VQQTestLogCallsite0()
    let lines = readfile(g:vqq_log_file)
    call s:assert.equals(len(lines), 1)
    call s:assert.includes(lines[0], 'test_log.vim:8')
endfunction

function s:suite.test_method_call()
    call vimqq#log#info('hello, world')
    let lines = readfile(g:vqq_log_file)
    call s:assert.equals(len(lines), 1)
    call s:assert.includes(lines[0], 'test_log.vim:23')
endfunction

function s:script_local_fn_call()
    call vimqq#log#info('hello, world')
endfunction

function s:suite.test_local_fn_call()
    call s:script_local_fn_call()
    let lines = readfile(g:vqq_log_file)
    call s:assert.equals(len(lines), 1)
    call s:assert.includes(lines[0], 'test_log.vim:30')
endfunction
