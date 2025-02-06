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

    function OnCompleteEmpty(new_index)
        call s:assert.length_of(keys(a:new_index), 1)
        call s:assert.has_key(a:new_index, 'a.txt')
        call s:assert.has_key(a:new_index['a.txt'], 'checksum')
        call s:assert.has_key(a:new_index['a.txt'], 'data')
    endfunction

    call vimqq#crawl#run(l:root, l:patterns, l:current_index, function('s:format_file'), function('OnCompleteEmpty'))

endfunction

function! s:suite.test_matching_checksum() abort
    let root = s:get_test_dir()
    let patterns = ['*.txt']

    " First create an index
    function OnCompleteMatched(first_index) closure
        " Run again with same index
        let l_first_index = deepcopy(a:first_index)

        function OnCompleteMatchedSecond(second_index) closure
            call s:assert.equals(l_first_index, a:second_index)
        endfunction

        call vimqq#crawl#run(root, patterns, a:first_index, function('s:format_file'), function('OnCompleteMatchedSecond'))

    endfunction

    call vimqq#crawl#run(l:root, l:patterns, {}, function('s:format_file'), function('OnCompleteMatched'))
endfunction

function! s:suite.test_mismatched_checksum() abort
    let root = s:get_test_dir()
    let patterns = ['*.txt']
    
    " Create initial index with a fake checksum
    let current_index = {
        \ 'a.txt': {
        \   'checksum': 'fake_checksum',
        \   'data': 'fake_data'
        \ }
    \ }

    function OnCompleteMismatched(new_index) closure
        call s:assert.not_equals(current_index['a.txt']['checksum'], a:new_index['a.txt']['checksum'])
        call s:assert.not_equals(current_index['a.txt']['data'], a:new_index['a.txt']['data'])

    endfunction

    call vimqq#crawl#run(root, patterns, current_index, function('s:format_file'), function('OnCompleteMismatched'))
    
endfunction
