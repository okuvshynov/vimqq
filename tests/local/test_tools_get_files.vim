let s:suite = themis#suite('test_tools_get_files.vim')
let s:assert = themis#helper('assert')

let s:path = expand('<sfile>:p:h')

function s:suite.test_get_files()
    let s:tool = vimqq#tools#get_files#new(s:path)

    let s:content = s:tool.run({'filepaths': ['tools_get_files.txt']})

    let s:expected = ['', 'tools_get_files.txt', 'Hello, world!']
    let s:expected = join(s:expected, "\n")
    call s:assert.equals(s:expected, s:content)
endfunction

function s:suite.test_get_files_not_found()
    let s:tool = vimqq#tools#get_files#new(s:path)

    let s:content = s:tool.run({'filepaths': ['non_existent_file.txt']})

    let s:expected = ['', 'non_existent_file.txt', 'ERROR: File not found.']
    let s:expected = join(s:expected, "\n")
    call s:assert.equals(s:expected, s:content)
endfunction

function s:suite.test_get_files_async()
    let s:tool = vimqq#tools#get_files#new(s:path)

    " Define expected value from synchronous run
    let s:expected = ['', 'tools_get_files.txt', 'Hello, world!']
    let s:expected = join(s:expected, "\n")

    " Spy variable to check if callback was called 
    let s:callback_called = 0

    " Define callback function
    function! s:test_callback(result) closure
        let s:callback_called = 1
        " Compare result with expected value
        call s:assert.equals(s:expected, a:result)
    endfunction

    " Run asynchronously
    call s:tool.run_async({'filepaths': ['tools_get_files.txt']}, function('s:test_callback'))

    " Check that callback was called
    call s:assert.equals(1, s:callback_called)
endfunction

function s:suite.test_get_files_async_not_found()
    let s:tool = vimqq#tools#get_files#new(s:path)

    " Define expected value from synchronous run 
    let s:expected = ['', 'non_existent_file.txt', 'ERROR: File not found.']
    let s:expected = join(s:expected, "\n")

    " Spy variable to check if callback was called
    let s:callback_called = 0

    " Define callback function 
    function! s:test_callback_not_found(result) closure
        let s:callback_called = 1
        " Compare result with expected value
        call s:assert.equals(s:expected, a:result)
    endfunction

    " Run asynchronously with non-existent file
    call s:tool.run_async({'filepaths': ['non_existent_file.txt']}, function('s:test_callback_not_found'))

    " Check that callback was called
    call s:assert.equals(1, s:callback_called)
endfunction
