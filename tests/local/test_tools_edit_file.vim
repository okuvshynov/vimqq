let s:suite = themis#suite('tools')
let s:assert = themis#helper('assert')

function s:suite.test_edit_file()
    let path = expand('<script>:p:h')
    let tool = vimqq#tools#edit_file#new(path)

    let content = ['hello', 'world']
    call writefile(content, path . '/test_edit_file.txt')

    let s:result = tool.run({'filepath': 'test_edit_file.txt', 'needle': 'hello', 'replacement': 'HELLO'})

    let s:expected = ['', 'test_edit_file.txt', 'SUCCESS: File updated successfully.']
    let s:expected = join(s:expected, '\n')
    call s:assert.equals(s:expected, s:result)

    let new_content = readfile(path . '/test_edit_file.txt')
    call s:assert.equals(new_content, ['HELLO', 'world'])
endfunction

function s:suite.test_edit_file_newline()
    let path = expand('<script>:p:h')
    let tool = vimqq#tools#edit_file#new(path)

    let content = ['hello', 'world']
    call writefile(content, path . '/test_edit_file.txt')

    let s:result = tool.run({'filepath': 'test_edit_file.txt', 'needle': "hello\nwo", 'replacement': 'hello, wo'})

    let s:expected = ['', 'test_edit_file.txt', 'SUCCESS: File updated successfully.']
    let s:expected = join(s:expected, '\n')
    call s:assert.equals(s:expected, s:result)

    let new_content = readfile(path . '/test_edit_file.txt')
    call s:assert.equals(new_content, ['hello, world'])
endfunction

function s:suite.test_edit_file_pattern_not_found()
    let path = expand('<script>:p:h')
    let tool = vimqq#tools#edit_file#new(path)

    let content = ['hello', 'world']
    call writefile(content, path . '/test_edit_file.txt')

    let s:result = tool.run({'filepath': 'test_edit_file.txt', 'needle': "hello!", 'replacement': ''})

    let s:expected = ['', 'test_edit_file.txt', 'ERROR: Pattern not found in file.']
    let s:expected = join(s:expected, '\n')
    call s:assert.equals(s:expected, s:result)

    let new_content = readfile(path . '/test_edit_file.txt')
    call s:assert.equals(new_content, content)
endfunction

function s:suite.test_edit_file_more_instances()
    let path = expand('<script>:p:h')
    let tool = vimqq#tools#edit_file#new(path)

    let content = ['hello', 'hello']
    call writefile(content, path . '/test_edit_file.txt')

    let s:result = tool.run({'filepath': 'test_edit_file.txt', 'needle': "hell", 'replacement': ''})

    let s:expected = ['', 'test_edit_file.txt', 'ERROR: Multiple instances of pattern found.']
    let s:expected = join(s:expected, '\n')
    call s:assert.equals(s:expected, s:result)

    let new_content = readfile(path . '/test_edit_file.txt')
    call s:assert.equals(new_content, content)
endfunction

function s:suite.test_edit_file_not_found()
    let path = expand('<script>:p:h')
    let tool = vimqq#tools#edit_file#new(path)

    let s:result = tool.run({'filepath': 'test_edit_file.txt', 'needle': "hello", 'replacement': ''})

    let s:expected = ['', 'test_edit_file.txt', 'ERROR: File not found.']
    let s:expected = join(s:expected, '\n')
    call s:assert.equals(s:expected, s:result)
endfunction

function s:suite.test_edit_file_async()
    let path = expand('<script>:p:h')
    let tool = vimqq#tools#edit_file#new(path)

    let content = ['hello', 'world']
    call writefile(content, path . '/test_edit_file.txt')

    " Store result in script-local variable that we can access from the callback
    let s:async_result = ''
    
    " Create callback function that stores the result
    function! s:callback(result)
        let s:async_result = a:result
    endfunction

    " Run the async operation
    call tool.run_async({'filepath': 'test_edit_file.txt', 'needle': 'hello', 'replacement': 'HELLO'}, function('s:callback'))

    " Since run_async is synchronous in implementation, we can check result immediately
    let s:expected = ['', 'test_edit_file.txt', 'SUCCESS: File updated successfully.']
    let s:expected = join(s:expected, '\n')
    call s:assert.equals(s:expected, s:async_result)

    " Verify file was actually updated
    let new_content = readfile(path . '/test_edit_file.txt')
    call s:assert.equals(new_content, ['HELLO', 'world'])
endfunction

function s:suite.after_each()
    let path = expand('<script>:p:h')
    call delete(path . '/test_edit_file.txt')
endfunction
