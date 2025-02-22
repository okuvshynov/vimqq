let s:suite = themis#suite('test_anthropic_api.vim')
let s:assert = themis#helper('assert')

let s:serv_path = expand('<sfile>:p:h:h') . '/mocks/mock_claude.py'
let s:skip_all = v:false

let s:MOCK_PORT = 8889

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
        \ [python_cmd, s:serv_path, '--port', s:MOCK_PORT],
        \ {'on_job': {job -> s:on_mock(job)}}
    \ )
    execute 'sleep 500m'
endfunction

function s:suite.test_stream_text()
    if s:skip_all
        call s:assert.skip(s:skip_msg)
        return
    endif

    let chunks = []
    let complted = v:false
    function! s:OnChunk(params, chunk) closure
        call add(chunks, a:chunk)
    endfunction

    function! s:OnComplete(err, params) closure
        let complted = v:true
    endfunction

    let api = vimqq#api#anthropic_api#new({'base_url': 'http://127.0.0.1:' . s:MOCK_PORT})

    let params = {
                \ 'messages': [{'role': 'user', 'content': 'Hello'}],
                \ 'stream': v:true,
                \ 'model': 'mock_model',
                \ 'on_chunk': function('s:OnChunk'),
                \ 'on_complete': function('s:OnComplete')
    \ }

    call api.chat(params)

    :sleep 500m

    let expected = 'Hello! How can I help you today?'
    call s:assert.equals(join(chunks, ''), expected)
endfunction
