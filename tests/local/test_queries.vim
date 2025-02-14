let s:suite = themis#suite('mock_server_queries')
let s:assert = themis#helper('assert')

function s:normtime(chat)
    let res = []
    for i in range(len(a:chat))
        call add(res, substitute(a:chat[i], '^\d\{2}:\d\{2}', '00:00', ''))
    endfor
    return res
endfunction

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
    let l:path = expand('<script>:p:h:h')
    let l:mock_serv = l:path . '/mock_llama.py'
    "echoe l:mock_serv
    let s:success = vimqq#platform#jobs#start(['python', l:mock_serv, '--port', '8888', '--logs', '/tmp/'], {'on_job': {job -> s:on_mock(job)}})
    execute 'sleep 1'
endfunction

function s:suite.after()
    call job_stop(s:server_job)
endfunction

function s:suite.before_each()
    :bufdo! bd! | enew
    call delete(g:vqq_chats_file)
    call vimqq#main#setup()
    let addr = g:vqq_llama_cpp_servers[0]['addr']
    call vimqq#platform#http#get(addr . '/reset', ["--max-time", "5"], {})
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
    let content = s:normtime(getline(1, '$'))
    let expected = ["00:00>l=165"]
    call s:assert.equals(content, expected)

    let l:server_stats = s:server_stats()
    let expected_stats = {"n_chat_queries": 3, "n_stream_queries": 1, "n_deltas": 3, "n_non_stream_queries": 1, "n_warmups": 1}
    call s:assert.equals(l:server_stats, expected_stats)
endfunction

function s:suite.test_new_chat()
    :QQ @mock hello
    :sleep 500m
    :QQN @mock world!
    :sleep 500m
    :QQList
    let content = s:normtime(getline(1, '$'))
    let expected = ["00:00>l=130", "00:00 l=129"]
    call s:assert.equals(content, expected)
    let l:server_stats = s:server_stats()
    let expected_stats = {"n_chat_queries": 6, "n_stream_queries": 2, "n_deltas": 6, "n_non_stream_queries": 2, "n_warmups": 2}
    call s:assert.equals(l:server_stats, expected_stats)
endfunction

function s:suite.test_new_chat_nodelay()
    :QQ @mock hello
    :QQN @mock world!
    :sleep 2000m
    :QQList

    let content = s:normtime(getline(1, '$'))
    " It is possible that we receive responses in 
    " any order, so last selected chat can be either of
    " them.
    let expected = [
        \ '00:00>l=130\n00:00 l=129',
        \ '00:00 l=130\n00:00>l=129'
    \ ]
    call s:assert.includes(expected, join(content, '\n'))
    let l:server_stats = s:server_stats()
    let expected_stats = {"n_chat_queries": 6, "n_stream_queries": 2, "n_deltas": 6, "n_non_stream_queries": 2, "n_warmups": 2}
    call s:assert.equals(l:server_stats, expected_stats)
endfunction

function s:suite.test_query()
    :QQ @mock hello
    :sleep 500m
    let content = s:normtime(getline(1, '$'))
    let expected = [
                \ "00:00 You: @mock hello",
                \ "00:00 mock: BEGIN",
                \ "hello",
                \ "END",
                \ "00:00 info: Setting title: l=129"
                \ ]
    call s:assert.equals(content, expected)
    let l:server_stats = s:server_stats()
    let expected_stats = {"n_chat_queries": 3, "n_stream_queries": 1, "n_deltas": 3, "n_non_stream_queries": 1, "n_warmups": 1}
    call s:assert.equals(l:server_stats, expected_stats)
endfunction

function s:suite.test_query_twice()
    :QQ @mock hello
    :sleep 500m
    :QQ @mock world!
    :sleep 500m

    let content = s:normtime(getline(1, '$'))
    let expected = [
                \ "00:00 You: @mock hello",
                \ "00:00 mock: BEGIN",
                \ "hello",
                \ "END",
                \ "00:00 info: Setting title: l=129",
                \ "00:00 You: @mock world!",
                \ "00:00 mock: BEGIN",
                \ "world!",
                \ "END"
                \ ]
    call s:assert.equals(content, expected)
    let l:server_stats = s:server_stats()
    let expected_stats = {"n_chat_queries": 4, "n_stream_queries": 2, "n_deltas": 6, "n_non_stream_queries": 1, "n_warmups": 1}
    call s:assert.equals(l:server_stats, expected_stats)
endfunction

function s:suite.test_queue()
    :QQ @mock hello
    :QQ @mock world!
    :sleep 1000m
    let content = s:normtime(getline(1, '$'))
    let expected = [
                \ "00:00 You: @mock hello",
                \ "00:00 info: Try sending your message after assistant reply is complete",
                \ "00:00 mock: BEGIN",
                \ "hello",
                \ "END",
                \ "00:00 info: Setting title: l=129"
                \ ]
    call s:assert.equals(content, expected)
    let l:server_stats = s:server_stats()
    let expected_stats = {'n_warmups': 1, 'n_deltas': 3, 'n_stream_queries': 1, 'n_non_stream_queries': 1, 'n_chat_queries': 3}
    call s:assert.equals(l:server_stats, expected_stats)
endfunction

function s:suite.test_selection()
    :put!=range(1,5)
    :normal ggV5j
    :execute "normal! \<Esc>"
    :'<,'>QQ @mock hello
    :sleep 1000m
    let content = s:normtime(getline(1, '$'))
    let expected = [
                \ "00:00 You: @mock Here's a code snippet:",
                \ "",
                \ "{{{ ...",
                \ "",
                \ "1",
                \ "2",
                \ "3",
                \ "4",
                \ "5",
                \ "",
                \ "",
                \ "}}}",
                \ "",
                \ "hello",
                \ "00:00 mock: BEGIN",
                \ "Here's a code snippet:",
                \ "",
                \ "1",
                \ "2",
                \ "3",
                \ "4",
                \ "5",
                \ "",
                \ "",
                \ "hello",
                \ "END",
                \ "00:00 info: Setting title: l=165"
    \ ]
    call s:assert.equals(content, expected)
    let l:server_stats = s:server_stats()
    let expected_stats = {"n_chat_queries": 3, "n_stream_queries": 1, "n_deltas": 3, "n_non_stream_queries": 1, "n_warmups": 1}
    call s:assert.equals(l:server_stats, expected_stats)
endfunction
