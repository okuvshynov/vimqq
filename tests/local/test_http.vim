let s:suite = themis#suite('platform_http_client')
let s:assert = themis#helper('assert')

let s:serv_path = expand('<sfile>:p:h:h') . '/mock_llama.py'

function OnMock(server_job)
    let s:server_job = a:server_job
endfunction

let s:skip_all = v:false

function s:suite.before()
	let python_cmd = vimqq#util#has_python()
	if python_cmd ==# ''
		let s:skip_all = v:true
		let s:skip_msg = 'python not found or flask package not installed'
		return
	endif

    let s:success = vimqq#platform#jobs#start([python_cmd, s:serv_path, '--port', '8888', '--logs', '/tmp/'], {'on_job': {job -> OnMock(job)}})
    execute 'sleep 5'
endfunction

function s:suite.after()
	if !s:skip_all
    	call job_stop(s:server_job)
	endif
endfunction

function s:suite.test_http_get()
	if s:skip_all
		call s:assert.skip(s:skip_msg)
	endif
    let reply_received = v:null
    function! OnOut(msg) closure
        let reply_received = a:msg
    endfunction

    let addr = g:vqq_llama_cpp_servers[0]['addr']
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/alive', ["--max-time", "5"], job_conf)

    execute 'sleep 1'
    call s:assert.equals(reply_received, 'alive')
endfunction

function s:suite.test_http_get_404()
	if s:skip_all
		call s:assert.skip(s:skip_msg)
	endif
    let status_code = 0
    function! OnOut(msg) closure
        let status_code = a:msg
    endfunction

    let addr = g:vqq_llama_cpp_servers[0]['addr']
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/non_existent', ["--max-time", "5", "-w", "%{http_code}", "-o", "/dev/null"], job_conf)

    execute 'sleep 1'
    call s:assert.equals(status_code, '404')
endfunction

function s:suite.test_http_get_na()
	if s:skip_all
		call s:assert.skip(s:skip_msg)
	endif
    let status_code = 0
    function! OnOut(msg) closure
        let status_code = a:msg
    endfunction

    let addr = g:vqq_llama_cpp_servers[0]['addr'] . '5'
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/non_existent', ["--max-time", "5", "-w", "%{http_code}", "-o", "/dev/null"], job_conf)

    execute 'sleep 1'
    call s:assert.equals(status_code, '000')
endfunction

function s:suite.test_http_get_na_body()
	if s:skip_all
		call s:assert.skip(s:skip_msg)
	endif
    let reply_received = []
    function! OnOut(msg) closure
        call add(reply_received, a:msg)
    endfunction

    let addr = g:vqq_llama_cpp_servers[0]['addr'] . '5'
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/non_existent', ["--max-time", "5"], job_conf)

    execute 'sleep 1'
    call s:assert.equals(join(reply_received, '\n'), '')
endfunction

