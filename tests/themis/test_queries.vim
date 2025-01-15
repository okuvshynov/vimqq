let s:suite = themis#suite('Query mock server')
let s:assert = themis#helper('assert')

function s:on_mock(server_job)
    let s:server_job = a:server_job
endfunction

function s:suite.before()
    let l:path = expand('<script>:p:h:h')
    let l:mock_serv = l:path . '/mock_llama.py'
    "echoe l:mock_serv
    let s:success = vimqq#platform#jobs#start(['python', l:mock_serv, '--port', '8888', '--logs', '/tmp/'], {'on_job': {job -> s:on_mock(job)}})
    execute 'sleep 1'
endfunction

function s:suite.after()
    call job_stop(s:server_job)
endfunction

function s:suite.test_list_one()
    " 5 lines with 1, 2, 3, 4, 5
    :put!=range(1,5)
    " visual select them
    :normal ggV5j
    " Call mock bot with the selection
    :execute "normal! \<Esc>"
    :'<,'>QQ @mock hello

    " sleep to get the reply
    :sleep 1

    " go to list
    :QQList
    let content = getline(1, '$')
    let expected = ["00:00>l=165"]
    call s:assert.equals(content, expected)
endfunction
