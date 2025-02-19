let s:suite = themis#suite('test_warmup.vim')
let s:assert = themis#helper('assert')

let s:serv_path = expand('<sfile>:p:h:h') . '/mock_llama.py'
let s:skip_all = v:false

function s:server_stats()
    let addr = g:vqq_llama_cpp_servers[0]['addr']
    let res = v:null
    function! OnOut(msg) closure
        let res = json_decode(a:msg)
    endfunction

    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/stats', ["--max-time", "1"], job_conf)
    :sleep 500m
    return res
endfunction

function s:on_mock(server_job)
    let s:server_job = a:server_job
endfunction

function s:suite.before()
	let python_cmd = vimqq#util#has_python()
	if python_cmd ==# ''
		let s:skip_all = v:true
		let s:skip_msg = 'python not found or flask package not installed'
		return
	endif
    let s:success = vimqq#platform#jobs#start(
        \ [python_cmd, s:serv_path, '--port', '8888', '--logs', '/tmp/'],
        \ {'on_job': {job -> s:on_mock(job)}}
    \ )
    execute 'sleep 1'
endfunction

function s:suite.after()
	if !s:skip_all
    	call job_stop(s:server_job)
	endif
endfunction

function s:suite.before_each()
	if !s:skip_all
		:bufdo! bd! | enew
		call delete(g:vqq_chats_file)
		call vimqq#main#setup()
		let addr = g:vqq_llama_cpp_servers[0]['addr']
		call vimqq#platform#http#get(addr . '/reset', ["--max-time", "5"], {})
	endif
endfunction

function s:suite.test_warmup()
	if s:skip_all
		call s:assert.skip(s:skip_msg)
	endif
    call vimqq#warmup#parse('QQ @mock hello')
    :sleep 2
    let l:server_stats = s:server_stats()
    let expected_stats = {"n_chat_queries": 1, "n_warmups": 1}
    call s:assert.equals(l:server_stats, expected_stats)
endfunction
