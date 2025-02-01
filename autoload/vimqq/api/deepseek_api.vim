if exists('g:autoloaded_vimqq_api_deepseek_module')
    finish
endif

let g:autoloaded_vimqq_api_deepseek_module = 1

let g:vqq_deepseek_api_key = get(g:, 'vqq_deepseek_api_key', $DEEPSEEK_API_KEY)

function! vimqq#api#deepseek_api#new() abort
    let api = {}

    " stores partial responses
    let api._replies = {}
    let api._req_id = 0
    let api._api_key = g:vqq_deepseek_api_key

    function! api._on_stream_out(msg, params) dict
        call vimqq#log#debug('deepseek msg ' . a:msg)
        let messages = split(a:msg, '\n')
        for message in messages
            if message !~# '^data: '
                call vimqq#log#warning('Unexpected reply: ' . message)
                continue
            endif
            if message ==# 'data: [DONE]'
                call a:params.on_complete(v:null, a:params)
                return
            endif
            let json_string = substitute(message, '^data: ', '', '')
            let response = json_decode(json_string)
            if has_key(response.choices[0].delta, 'content')
                let chunk = response.choices[0].delta.content
                if chunk isnot v:null
                  call a:params.on_chunk(a:params, chunk)
                endif
            endif
            if has_key(response.choices[0].delta, 'reasoning_content')
                let chunk = response.choices[0].delta.reasoning_content
                if chunk isnot v:null
                  call a:params.on_chunk(a:params, chunk)
                endif
            endif
        endfor
    endfunction

    " Not calling any callback as we expect to act on data: [DONE]
    function! api._on_stream_close(params) dict
        call vimqq#log#debug('deepseek_api stream closed.')
    endfunction

    function! api._on_out(msg, params, req_id) dict
        if !has_key(self._replies, a:req_id)
            call vimqq#log#error('deepseek_api: reply for non-existent request: ' . a:req_id)
            return
        endif
        call add(self._replies[a:req_id], a:msg)
    endfunction

    function! api._on_close(params, req_id) dict
        if !has_key(self._replies, a:req_id)
            call vimqq#log#error('deepseek_api: reply for non-existent request: ' . a:req_id)
            return
        endif
        let response = join(self._replies[a:req_id], '\n')
        let response = json_decode(l:response)
        if has_key(response, 'choices') && !empty(l:response.choices) && has_key(l:response.choices[0], 'message')
            let message = l:response.choices[0].message.content
            if has_key(a:params, 'on_chunk')
                call a:params.on_chunk(a:params, message)
            endif
            if has_key(a:params, 'on_complete')
                call a:params.on_complete(v:null, a:params)
            endif
        else
            call vimqq#log#error('deepseek_api: Unable to process response')
            call vimqq#log#error(json_encode(response))
        endif
    endfunction

    function! api._on_error(msg, params) dict
        call vimqq#log#error('API error')
    endfunction

    function! api.chat(params) dict
        let req = {
        \   'messages': get(a:params, 'messages', []),
        \   'model': a:params.model,
        \   'max_tokens': get(a:params, 'max_tokens', 1024),
        \   'stream': get(a:params, 'stream', v:false)
        \ }

        let req_id = self._req_id
        let self._req_id = self._req_id + 1
        let self._replies[req_id] = []

        if req.stream
            let job_conf = {
            \   'out_cb': {channel, msg -> self._on_stream_out(msg, a:params)},
            \   'err_cb': {channel, msg -> self._on_error(msg, a:params)},
            \   'close_cb': {channel -> self._on_stream_close(a:params)},
            \ }
        else
            let job_conf = {
            \   'out_cb': {channel, msg -> self._on_out(msg, a:params, req_id)},
            \   'err_cb': {channel, msg -> self._on_error(msg, a:params, req_id)},
            \   'close_cb': {channel -> self._on_close(a:params, req_id)}
            \ }
        endif

        let json_req = json_encode(req)
        let headers = {
            \ 'Content-Type': 'application/json',
            \ 'Accept': 'application/json',
            \ 'Authorization': 'Bearer ' . self._api_key
        \ }
        return vimqq#platform#http#post(
            \ 'https://api.deepseek.com/chat/completions',
            \ headers,
            \ json_req,
            \ job_conf)
    endfunction

    return api

endfunction
