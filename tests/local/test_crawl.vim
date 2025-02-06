let s:suite = themis#suite('vimqq#crawl')
let s:assert = themis#helper('assert')

function! s:format_file(filepath) abort
    " Simple test procedure function that returns file content
    return join(readfile(a:filepath), "\n")
endfunction

function! s:get_test_dir() abort
    " Get path to test_dir relative to test file
    return fnamemodify(expand('<script>'), ':p:h') . '/test_dir'
endfunction

function! s:suite.test_empty_index() abort
    let l:root = s:get_test_dir()
    let l:patterns = ['*.txt']
    let l:current_index = {}

    let l:new_index = vimqq#crawl#run(l:root, l:patterns, l:current_index, function('s:format_file'))

    call s:assert.length_of(keys(l:new_index), 1)
    call s:assert.has_key(l:new_index, 'a.txt')
    call s:assert.has_key(l:new_index['a.txt'], 'checksum')
    call s:assert.has_key(l:new_index['a.txt'], 'data')
endfunction

function! s:suite.test_matching_checksum() abort
    let l:root = s:get_test_dir()
    let l:patterns = ['*.txt']
    
    " First create an index
    let l:current_index = vimqq#crawl#run(l:root, l:patterns, {}, function('s:format_file'))
    
    " Run again with same index
    let l:new_index = vimqq#crawl#run(l:root, l:patterns, l:current_index, function('s:format_file'))

    " Should be exactly the same
    call s:assert.equals(l:current_index, l:new_index)
endfunction

function! s:suite.test_mismatched_checksum() abort
    let l:root = s:get_test_dir()
    let l:patterns = ['*.txt']
    
    " Create initial index with a fake checksum
    let l:current_index = {
        \ 'a.txt': {
        \   'checksum': 'fake_checksum',
        \   'data': 'fake_data'
        \ }
    \ }
    
    " Run with mismatched index
    let l:new_index = vimqq#crawl#run(l:root, l:patterns, l:current_index, function('s:format_file'))

    call s:assert.not_equals(l:current_index['a.txt']['checksum'], l:new_index['a.txt']['checksum'])
    call s:assert.not_equals(l:current_index['a.txt']['data'], l:new_index['a.txt']['data'])
endfunction
