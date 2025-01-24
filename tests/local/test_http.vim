let s:suite = themis#suite('platform_http_client')
let s:assert = themis#helper('assert')

function OnMock(server_job)
    let s:server_job = a:server_job
endfunction

function s:suite.before()
    let l:path = expand('<script>:p:h:h')
    let l:mock_serv = l:path . '/mock_llama.py'
    let s:success = vimqq#platform#jobs#start(['python', l:mock_serv, '--port', '8888', '--logs', '/tmp/'], {'on_job': {job -> OnMock(job)}})
    execute 'sleep 1'
endfunction

function s:suite.after()
    call job_stop(s:server_job)
endfunction

function s:suite.test_http_get()
    let reply_received = v:null
    function! OnOut(msg) closure
        let reply_received = a:msg
    endfunction

    let addr = g:vqq_llama_servers[0]['addr']
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/alive', ["--max-time", "5"], job_conf)

    execute 'sleep 1'
    call s:assert.equals(reply_received, 'alive')
endfunction

function s:suite.test_http_get_404()
    let status_code = 0
    function! OnOut(msg) closure
        let status_code = a:msg
    endfunction

    let addr = g:vqq_llama_servers[0]['addr']
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/non_existent', ["--max-time", "5", "-w", "%{http_code}", "-o", "/dev/null"], job_conf)

    execute 'sleep 1'
    call s:assert.equals(status_code, '404')
endfunction

function s:suite.test_http_get_na()
    let status_code = 0
    function! OnOut(msg) closure
        let status_code = a:msg
    endfunction

    let addr = g:vqq_llama_servers[0]['addr'] . '5'
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/non_existent', ["--max-time", "5", "-w", "%{http_code}", "-o", "/dev/null"], job_conf)

    execute 'sleep 1'
    call s:assert.equals(status_code, '000')
endfunction

function s:suite.test_http_get_na_body()
    let reply_received = []
    function! OnOut(msg) closure
        call add(reply_received, a:msg)
    endfunction

    let addr = g:vqq_llama_servers[0]['addr'] . '5'
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/non_existent', ["--max-time", "5"], job_conf)

    execute 'sleep 1'
    call s:assert.equals(join(reply_received, '\n'), '')
endfunction

