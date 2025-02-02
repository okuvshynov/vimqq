if exists('g:autoloaded_vimqq_api_anthropic_module')
    finish
endif

let g:autoloaded_vimqq_api_anthropic_module = 1

let g:vqq_claude_api_key = get(g:, 'vqq_claude_api_key', $ANTHROPIC_API_KEY)
let g:vqq_claude_cache_above = get(g:, 'vqq_claude_cache_above', 5000)

function! vimqq#api#anthropic_api#new() abort
    let api = {}

    let api._req_id = 0
    let api._replies = {}
    let api._tool_uses = {}
    let api._api_key = g:vqq_claude_api_key
    let api._usage = {}

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
                " Likely an error, let's try deserialize it
                try
                    let error_json = json_decode(message)
                    if error_json['type'] == 'error'
                        let err = string(error_json['error'])
                        if has_key(a:params, 'on_sys_msg')
                            call a:params.on_sys_msg('error', err)
                        endif
                        call vimqq#log#error(err)
                    else
                        let warn = 'Unexpected message received: ' . message
                        call vimqq#log#warning(warn)
                    endif
                catch
                    let warn = 'Unexpected message received: ' . message
                    call vimqq#log#warning(warn)
                endtry
                continue
            endif
            let json_string = substitute(message, '^data: ', '', '')
            call vimqq#log#debug('ANTHROPIC REPLY: ' . json_string)
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
                " Here we get usage for input tokens
                call vimqq#log#debug('usage: ' . string(response.message.usage))
                let self._usage = vimqq#agg#merge(self._usage, response.message.usage)

                continue
            endif
            if response['type'] ==# 'message_stop'
                " First param is 'error'
                call a:params.on_complete(v:null, a:params)
                continue
            endif
            if response['type'] ==# 'message_delta'
                " Here we get usage for output
                call vimqq#log#debug('usage: ' . string(response.usage))
                let self._usage = vimqq#agg#merge(self._usage, response.usage)
                if has_key(a:params, 'on_sys_msg')
                    call a:params.on_sys_msg('info', string(self._usage))
                endif
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
        let response = json_decode(join(self._replies[a:req_id], "\n"))
        if has_key(response, 'content') && !empty(l:response.content) && has_key(l:response.content[0], 'text')
            call vimqq#log#debug('usage: ' . string(response.usage))
            let self._usage = vimqq#agg#merge(self._usage, response.usage)
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

    function! api._count_tokens(messages, tools, model, system_msg) dict
        let req = {
            \ 'model': a:model,
            \ 'messages': a:messages,
            \ 'tools': a:tools
        \ }
        if a:system_msg isnot v:null
            let req['system'] = a:system_msg
        endif

        let headers = {
            \ 'Content-Type': 'application/json',
            \ 'x-api-key': self._api_key,
            \ 'anthropic-version': '2023-06-01'
        \ }
        let json_req = json_encode(req)
		let job_conf = {
		\   'out_cb': {channel, msg -> vimqq#log#debug('token count: ' . msg)}
		\ }
        return vimqq#platform#http#post(
            \ 'https://api.anthropic.com/v1/messages/count_tokens',
            \ headers,
            \ json_req,
            \ job_conf)
    endfunction

    function! api.chat(params) dict
        let messages = a:params.messages
        let tools = get(a:params, 'tools', [])
        
        let system_msg = v:null
        if messages[0].role ==# 'system'
            let system_msg = l:messages[0].content
            call remove(messages, 0)
        endif

        " Count tokens before proceeding
        " call self._count_tokens(messages, tools, a:params.model, system_msg)
        

        let req = {
        \   'messages' : messages,
        \   'model': a:params.model,
        \   'max_tokens' : get(a:params, 'max_tokens', 1024),
        \   'stream': get(a:params, 'stream', v:false),
        \   'tools': get(a:params, 'tools', [])
        \}

        let first_message_json = json_encode(messages[0])
        if len(first_message_json) > g:vqq_claude_cache_above
            let req.messages[0]['content'][0]['cache_control'] = {"type": "ephemeral"}
        endif

        if system_msg isnot v:null
            let req['system'] = system_msg
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
        call vimqq#log#debug('JSON_REQ: ' . json_req)
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
