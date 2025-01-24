if exists('g:autoloaded_vimqq_api_anthropic_module')
    finish
endif

let g:autoloaded_vimqq_api_anthropic_module = 1

let g:vqq_claude_api_key = get(g:, 'vqq_claude_api_key', $ANTHROPIC_API_KEY)

function! vimqq#api#anthropic_api#new() abort
    let api = {}

    let api._req_id = 0
    let api._replies = {}
    let api._tool_uses = {}
    let api._api_key = g:vqq_claude_api_key

    function! api._on_error(msg, params) dict
        call vimqq#log#error('API error')
    endfunction

    " Not calling any callback as we expect to act on data: [DONE]
    function! api._on_stream_close(params) dict
        call vimqq#log#debug('anthropic stream closed.')
    endfunction

    function! api._on_stream_out(msg, params, req_id) dict
        let messages = split(a:msg, '\n')
        for message in messages
            if message !~# '^data: '
                continue
            endif
            let json_string = substitute(message, '^data: ', '', '')
            let response = json_decode(json_string)

            if response['type'] ==# 'content_block_start'
                if response['content_block']['type'] ==# 'tool_use'
                    let tool_name = response['content_block']['name']
                    let tool_id = response['content_block']['id']
                    let self._tool_uses[a:req_id] = {
                        \ 'name': tool_name,
                        \ 'input': '',
                        \ 'id': tool_id 
                    \ }
                endif
            endif

            if response['type'] ==# 'message_start'
                continue
            endif
            if response['type'] ==# 'message_stop'
                " First param is 'error'
                call a:params.on_complete(v:null, a:params)
                continue
            endif
            if response['type'] ==# 'message_delta'
                if response['delta']['stop_reason'] ==# 'tool_use'
                    let self._tool_uses[a:req_id]['input'] = json_decode(self._tool_uses[a:req_id]['input'])
                    call a:params.on_tool_use(self._tool_uses[a:req_id])
                endif
                continue
            endif
            if response['type'] ==# 'content_block_delta'
                if response['delta']['type'] ==# 'text_delta'
                    let chunk = response.delta.text
                    call a:params.on_chunk(a:params, chunk)
                endif
                if response['delta']['type'] ==# 'input_json_delta'
                    let chunk = response.delta.partial_json
                    let self._tool_uses[a:req_id]['input'] .= chunk
                endif
            endif
        endfor
    endfunction

    function! api._on_out(msg, params, req_id) dict
        if !has_key(self._replies, a:req_id)
            call vimqq#log#error('anthropic: reply for non-existent request: ' . a:req_id)
            return
        endif
        call add(self._replies[a:req_id], a:msg)
    endfunction

    function! api._on_close(params, req_id) dict
        let response = json_decode(join(self._replies[a:req_id], '\n'))
        if has_key(response, 'content') && !empty(l:response.content) && has_key(l:response.content[0], 'text')
            let message = l:response.content[0].text
            if has_key(a:params, 'on_chunk')
                call a:params.on_chunk(a:params, message)
            endif
            if has_key(a:params, 'on_complete')
                call a:params.on_complete(v:null, a:params)
            endif
        else
            call vimqq#log#error('Unable to process response')
            call vimqq#log#error(json_encode(response))
            " TODO: still need to call on_complete with error?
        endif
    endfunction

    function! api.chat(params) dict
        let messages = a:params.messages
        let system = v:null
        if messages[0].role ==# 'system'
            let system = l:messages[0].content
            call remove(messages, 0)
        endif

        let req = {
        \   'messages' : messages,
        \   'model': a:params.model,
        \   'max_tokens' : get(a:params, 'max_tokens', 1024),
        \   'stream': get(a:params, 'stream', v:false),
        \   'tools': get(a:params, 'tools', [])
        \}

        if system isnot v:null
            let req['system'] = system
        endif

        let req_id = self._req_id
        let self._req_id = self._req_id + 1
        let self._replies[req_id] = []
        let self._tool_uses[req_id] = []

        if req.stream
            let job_conf = {
            \   'out_cb': {channel, msg -> self._on_stream_out(msg, a:params, req_id)},
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
            \ 'x-api-key': self._api_key,
            \ 'anthropic-version': '2023-06-01'
        \ }
        return vimqq#platform#http#post(
            \ 'https://api.anthropic.com/v1/messages',
            \ headers,
            \ json_req,
            \ job_conf)

    endfunction

    return api
endfunction
