let s:suite = themis#suite('Tool run_cmd')
let s:assert = themis#helper('assert')

function! s:suite.test_ls()
    let path = expand('%:p:h')
    let tool = vimqq#tools#run_cmd#new(path)

    function! OnComplete(result)
        let s:async_result = a:result
    endfunction

    call tool.run_async({'command': 'echo "hello, world"'}, function('OnComplete'))

    :sleep 1000m

    let result = json_decode(s:async_result)

    call s:assert.equals(result.stderr, "")
    call s:assert.equals(result.stdout, "hello, world")
    call s:assert.equals(result.returncode, 0)
endfunction

