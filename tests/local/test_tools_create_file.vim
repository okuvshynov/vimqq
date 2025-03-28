let s:suite = themis#suite('test_tools_create_file.vim')

function! s:suite.test_create_file()
    let path = expand('%:p:h')
    let tool = vimqq#tools#create_file#new(path)
    let content = ['test line 1', 'test line 2']

    let s:result = tool.run({'filepath': 'test_create_file.txt', 'content': join(content, "\n")})

    let s:expected = ['', 'test_create_file.txt', 'SUCCESS: File created successfully.']
    call assert_equal(join(s:expected, "\n"), s:result)

    " Test that file was created with correct content
    let new_content = readfile(path . '/test_create_file.txt')
    call assert_equal(content, new_content)
endfunction

function! s:suite.test_create_file_exists()
    let path = expand('%:p:h')
    let tool = vimqq#tools#create_file#new(path)

    " First create a file
    let content = ['existing content']
    call writefile(content, path . '/test_create_file.txt')

    " Try to create it again
    let s:result = tool.run({'filepath': 'test_create_file.txt', 'content': 'new content'})

    let s:expected = ['', 'test_create_file.txt', 'ERROR: File already exists.']
    call assert_equal(join(s:expected, "\n"), s:result)

    " Verify original content was not changed
    let new_content = readfile(path . '/test_create_file.txt')
    call assert_equal(content, new_content)
endfunction

" Clean up after each test
function! s:suite.test_create_file_async()
    let path = expand('%:p:h')
    let tool = vimqq#tools#create_file#new(path)
    let content = ['test line 1', 'test line 2']
    let s:async_result = ''

    function! OnComplete(result)
        let s:async_result = a:result
    endfunction

    call tool.run_async({'filepath': 'test_create_file.txt', 'content': join(content, "\n")}, function('OnComplete'))
    
    " Since run_async immediately calls run in this implementation, we can check the result right away
    let s:expected = ['', 'test_create_file.txt', 'SUCCESS: File created successfully.']
    call assert_equal(join(s:expected, "\n"), s:async_result)

    " Test that file was created with correct content
    let new_content = readfile(path . '/test_create_file.txt')
    call assert_equal(content, new_content)
endfunction

function! s:suite.test_create_file_async_exists()
    let path = expand('%:p:h')
    let tool = vimqq#tools#create_file#new(path)
    let s:async_result = ''

    " First create a file
    let content = ['existing content']
    call writefile(content, path . '/test_create_file.txt')

    function! OnComplete(result)
        let s:async_result = a:result
    endfunction

    " Try to create it again asynchronously
    call tool.run_async({'filepath': 'test_create_file.txt', 'content': 'new content'}, function('OnComplete'))
    
    " Since run_async immediately calls run in this implementation, we can check the result right away
    let s:expected = ['', 'test_create_file.txt', 'ERROR: File already exists.']
    call assert_equal(join(s:expected, "\n"), s:async_result)

    " Verify original content was not changed
    let new_content = readfile(path . '/test_create_file.txt')
    call assert_equal(content, new_content)
endfunction

function s:suite.after_each()
    call delete(expand('%:p:h') . '/test_create_file.txt')
endfunction
