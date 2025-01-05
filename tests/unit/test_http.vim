"
" testing platform/http module

let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../libtest.vim"
execute "source " . s:lib

function! Test_http_get()
    let reply_received = v:null
    function! OnOut(msg) closure
        let reply_received = a:msg
    endfunction

    let addr = g:vqq_llama_servers[0]['addr']
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/alive', ["--max-time", "5"], job_conf)

    execute 'sleep 1'
    call ASSERT_EQ(reply_received, 'alive')
endfunction

function! Test_http_get_404()
    let status_code = 0
    function! OnOut(msg) closure
        call vimqq#log#info(a:msg)
        let status_code = a:msg
    endfunction

    let addr = g:vqq_llama_servers[0]['addr']
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/non_existent', ["--max-time", "5", "-w", "%{http_code}", "-o", "/dev/null"], job_conf)

    execute 'sleep 1'
    call ASSERT_EQ(status_code, '404')
endfunction

function! Test_http_get_na()
    let status_code = 0
    function! OnOut(msg) closure
        call vimqq#log#info(a:msg)
        let status_code = a:msg
    endfunction

    let addr = g:vqq_llama_servers[0]['addr'] . '5'
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/non_existent', ["--max-time", "5", "-w", "%{http_code}", "-o", "/dev/null"], job_conf)

    execute 'sleep 1'
    call ASSERT_EQ(status_code, '000')
endfunction

function! Test_http_get_na_body()
    let reply_received = []
    function! OnOut(msg) closure
        call vimqq#log#info(a:msg)
        call add(reply_received, a:msg)
    endfunction

    let addr = g:vqq_llama_servers[0]['addr'] . '5'
    let job_conf = {'out_cb': {channel, msg -> OnOut(msg)}}
    call vimqq#platform#http#get(addr . '/non_existent', ["--max-time", "5"], job_conf)

    execute 'sleep 1'
    call ASSERT_EQ(join(reply_received, '\n'), '')
endfunction

call RunAllTests()
