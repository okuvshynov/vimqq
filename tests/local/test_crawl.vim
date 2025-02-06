let s:suite = themis#suite('vimqq#crawl')
let s:assert = themis#helper('assert')

function! s:format_file(filepath, CompleteFn) abort
    " Simple test procedure function that returns file content
    let full_path = s:get_test_dir() . "/" . a:filepath
    call call(a:CompleteFn, [a:filepath, join(readfile(full_path), "\n")])
endfunction

function! s:get_test_dir() abort
    " Get path to test_dir relative to test file
    return fnamemodify(expand('<script>'), ':p:h') . '/test_dir'
endfunction

function! s:suite.test_empty_index() abort
    let root = s:get_test_dir()
    let patterns = ['a.txt']
    let current_index = {}

    let n_called = 0

    function OnCompleteEmpty(new_index) closure
        call s:assert.length_of(keys(a:new_index), 1)
        call s:assert.has_key(a:new_index, 'a.txt')
        call s:assert.has_key(a:new_index['a.txt'], 'checksum')
        call s:assert.has_key(a:new_index['a.txt'], 'data')
        let n_called += 1
    endfunction

    call vimqq#crawl#run(root, patterns, current_index, function('s:format_file'), function('OnCompleteEmpty'))

    :sleep 10m
    call s:assert.equals(n_called, 1)
endfunction

function! s:suite.test_matching_checksum() abort
    let root = s:get_test_dir()
    let patterns = ['a.txt']

    let n_called = 0

    " First create an index
    function OnCompleteMatched(first_index) closure
        " Run again with same index
        let l_first_index = deepcopy(a:first_index)
        let n_called += 1
        let n_called_in = 0

        function OnCompleteMatchedSecond(second_index) closure
            let n_called_in += 1
            call s:assert.equals(l_first_index, a:second_index)
        endfunction

        call vimqq#crawl#run(root, patterns, a:first_index, function('s:format_file'), function('OnCompleteMatchedSecond'))
        :sleep 10m
        call s:assert.equals(n_called_in, 1)

    endfunction

    call vimqq#crawl#run(root, patterns, {}, function('s:format_file'), function('OnCompleteMatched'))
    :sleep 10m
    call s:assert.equals(n_called, 1)
endfunction

function! s:suite.test_mismatched_checksum() abort
    let root = s:get_test_dir()
    let patterns = ['a.txt']
    
    " Create initial index with a fake checksum
    let current_index = {
        \ 'a.txt': {
        \   'checksum': 'fake_checksum',
        \   'data': 'fake_data'
        \ }
    \ }

    let n_called = 0

    function OnCompleteMismatched(new_index) closure
        let n_called += 1
        call s:assert.not_equals(current_index['a.txt']['checksum'], a:new_index['a.txt']['checksum'])
        call s:assert.not_equals(current_index['a.txt']['data'], a:new_index['a.txt']['data'])

    endfunction

    call vimqq#crawl#run(root, patterns, current_index, function('s:format_file'), function('OnCompleteMismatched'))
    
    :sleep 10m
    call s:assert.equals(n_called, 1)
endfunction

function! s:suite.test_two_files() abort
    let root = s:get_test_dir()
    let patterns = ['*.txt']
    let current_index = {}

    let n_called = 0

    function OnTestTwoComplete(new_index) closure
        call s:assert.length_of(keys(a:new_index), 2)
        call s:assert.has_key(a:new_index, 'a.txt')
        call s:assert.has_key(a:new_index, 'b.txt')
        call s:assert.has_key(a:new_index['a.txt'], 'checksum')
        call s:assert.has_key(a:new_index['a.txt'], 'data')
        call s:assert.has_key(a:new_index['b.txt'], 'checksum')
        call s:assert.has_key(a:new_index['b.txt'], 'data')
        let n_called += 1
    endfunction

    call vimqq#crawl#run(root, patterns, current_index, function('s:format_file'), function('OnTestTwoComplete'))

    :sleep 10m
    call s:assert.equals(n_called, 1)
endfunction
