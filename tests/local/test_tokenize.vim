let s:suite = themis#suite('test_tokenize.vim')
let s:assert = themis#helper('assert')

let s:serv_path = expand('<sfile>:p:h:h') . '/mocks/mock_llama_cpp.py'
let s:skip_all = v:false

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

function s:suite.test_tokenize()
    if s:skip_all
        call s:assert.skip(s:skip_msg)
    endif
    let conf = {}
    let conf.endpoint = g:vqq_llama_cpp_servers[0]['addr']
    let api = vimqq#api#llama_api#new(conf)

    let tokens = []
    let completed = v:false
    function! s:OnTokenized(tokens) closure
        let tokens = a:tokens
        let completed = v:true
    endfunction

    let params = {'on_complete' : {t -> s:OnTokenized(t)}}

    call api.tokenize("hello, world!", params)

    :sleep 1

    call s:assert.equals(completed, v:true)
    call s:assert.equals(tokens, ["hello,", "world!"])

endfunction

function s:suite.test_token_count()
    if s:skip_all
        call s:assert.skip(s:skip_msg)
    endif
    let indexer_bot = vimqq#bots#llama_cpp_indexer#new(g:vqq_llama_cpp_servers[0])

    let token_count = 0
    function! s:OnCounted(token_count) closure
        let token_count = a:token_count
    endfunction

    let req = {
        \ 'content': 'quick brown fox jumped',
        \ 'on_complete' : {tc -> s:OnCounted(tc)}
    \ }

    call indexer_bot.count_tokens(req)

    :sleep 1

    call s:assert.equals(token_count, 4)

endfunction
