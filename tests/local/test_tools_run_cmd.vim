let s:suite = themis#suite('test_tools_run_cmd.vim')
let s:assert = themis#helper('assert')

let s:path = expand('<sfile>:p:h')

function! s:suite.test_echo()
    let tool = vimqq#tools#run_cmd#new(s:path)

    function! OnComplete(result)
        let s:async_result = a:result
    endfunction

    call tool.run_async({'command': 'echo "hello, world"'}, function('OnComplete'))

    :sleep 100m

    let result = json_decode(s:async_result)

    call s:assert.equals(result.stderr, "")
    call s:assert.equals(result.stdout, "hello, world")
    call s:assert.equals(result.returncode, 0)
endfunction

function! s:suite.test_ls()
    let tool = vimqq#tools#run_cmd#new(s:path)

    function! OnComplete(result)
        let s:async_result = a:result
    endfunction

    call tool.run_async({'command': 'ls test_dir'}, function('OnComplete'))

    :sleep 100m

    let result = json_decode(s:async_result)

    call s:assert.equals(result.stderr, "")
    call s:assert.equals(result.stdout, "a.txt\nb.txt")
    call s:assert.equals(result.returncode, 0)
endfunction

function! s:suite.test_nonexistent_dir()
    let tool = vimqq#tools#run_cmd#new(s:path)

    function! OnComplete(result)
        let s:async_result = a:result
    endfunction

    call tool.run_async({'command': 'ls nonexistent_directory'}, function('OnComplete'))

    :sleep 100m

    let result = json_decode(s:async_result)

    call s:assert.equals(result.stdout, "")
    call s:assert.compare(result.returncode, '>', 0)
endfunction

