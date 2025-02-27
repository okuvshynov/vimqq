if exists('g:autoloaded_vimqq_api_anthropic_module')
    finish
endif

let g:autoloaded_vimqq_api_anthropic_module = 1

let g:vqq_claude_api_key = get(g:, 'vqq_claude_api_key', $ANTHROPIC_API_KEY)
let g:vqq_claude_cache_above = get(g:, 'vqq_claude_cache_above', 5000)

" Translates tool definition schema to Claude-compatible format
" Public for unit testing
function! vimqq#api#anthropic_api#to_claude(schema)
    let fn = a:schema['function']
    let res = {
    \   'name': fn['name'],
    \   'description' : fn['description'],
    \   'input_schema' : fn['parameters']
    \} 
    return res
endfunction

" config is unused for now
function! vimqq#api#anthropic_api#new(conf = {}) abort
    let api = {}

    let api._base_url = get(a:conf, 'base_url', 'https://api.anthropic.com')
    let api._req_id = 0
    let api._replies = {}
    let api._api_key = g:vqq_claude_api_key
    " TODO: !! this is wrong needs to be per request
    let api._usage = {}
    " TODO: !! this is wrong needs to be per request
    let api._last_turn_usage = {}

    let api._builders = {}

    function! api._on_error(msg, params) dict
        call vimqq#log#error('API error')
    endfunction

    " Not calling any callback as we expect to act on data: [DONE]
    function! api._on_stream_close(params) dict
        call vimqq#log#debug('anthropic stream closed.')
        " Still need to close in case of error?
    endfunction

    function! api._on_stream_out(data, params, req_id) dict
        let SysMessage = get(a:params, 'on_sys_msg', {l, m -> 0})

        let builder = self._builders[a:req_id]

        for event in split(a:data, '\n')
            if event =~# '^event: '
                call vimqq#log#debug(event)
                continue
            endif
            if event !~# '^data: '
                " Likely an error, let's try deserialize it
                try
                    let error_json = json_decode(event)
                    if error_json['type'] == 'error'
                        let err = string(error_json['error'])
                        if get(error_json['error'], 'type', '') ==# 'rate_limit_error'
                            call SysMessage(
                                \ 'warning',
                                \ 'Reached rate limit. Waiting 60s before retry'
                            \ )

                            call timer_start(60000, { timer_id -> self.chat(a:params)})
                            return
                        endif
                        call SysMessage('error', err)
                        call vimqq#log#error(err)
                    else
                        let warn = 'Unexpected event received: ' . event
                        call vimqq#log#warning(warn)
                    endif
                catch
                    let warn = 'Unexpected event received: ' . event
                    call vimqq#log#warning(warn)
                endtry
                continue
            endif
            let json_string = substitute(event, '^data: ', '', '')
            let response = json_decode(json_string)

            if response['type'] ==# 'message_start'
                let self._usage = vimqq#util#merge(self._usage, response.message.usage)
                let self._last_turn_usage = response.message.usage
                continue
            endif

            if response['type'] ==# 'content_block_start'
                call builder.content_block_start(response['index'], response['content_block'])
                continue
            endif
            
            if response['type'] ==# 'content_block_delta'
                call builder.content_block_delta(response['index'], response['delta'])
                continue
            endif

            if response['type'] ==# 'content_block_stop'
                call builder.content_block_stop(response['index'])
                continue
            endif

            if response['type'] ==# 'message_delta'
                " Here we get usage for output
                call vimqq#log#debug('usage: ' . string(response.usage))
                let self._usage = vimqq#util#merge(self._usage, response.usage)

                let in_tokens = get(self._last_turn_usage, 'cache_creation_input_tokens', 0) +
                            \ get(self._last_turn_usage, 'cache_read_input_tokens', 0) +
                            \ get(self._last_turn_usage, 'input_tokens', 0)

                let out_tokens = get(response.usage, 'output_tokens', 0)
                call SysMessage('info', 'Turn: in = ' . in_tokens . ', out = ' . out_tokens)

                let in_tokens = get(self._usage, 'cache_creation_input_tokens', 0) +
                            \ get(self._usage, 'cache_read_input_tokens', 0) +
                            \ get(self._usage, 'input_tokens', 0)

                let out_tokens = get(self._usage, 'output_tokens', 0)

                call SysMessage('info', 'Conversation: in = ' . in_tokens . ', out = ' . out_tokens)
                continue
            endif

            if response['type'] ==# 'message_stop'
                call builder.message_stop()
                continue
            endif
        endfor
    endfunction

    function! api._on_out(msg, params, req_id) dict
        let builder = self._builders[a:req_id]
        call builder.part(a:msg)
    endfunction

    function! api._on_close(params, req_id) dict
        let builder = self._builders[a:req_id]
        call builder.close()
    endfunction

    function! api.adapt_tool_def(tools) dict
        let res = []
        for tool in a:tools
            call add(res, vimqq#api#anthropic_api#to_claude(tool))
        endfor
        return res
    endfunction

    function! api.chat(params) dict
        let params = deepcopy(a:params)
        let messages = params.messages
        let tools = get(params, 'tools', [])
        
        let system_msg = v:null
        if messages[0].role ==# 'system'
            let system_msg = l:messages[0].content
            call remove(messages, 0)
        endif

        let req = {
        \   'messages' : messages,
        \   'model': params.model,
        \   'max_tokens' : get(params, 'max_tokens', 1024),
        \   'stream': get(params, 'stream', v:false),
        \   'tools': self.adapt_tool_def(tools)
        \}

        let first_message_json = json_encode(messages[0])
        if len(first_message_json) > g:vqq_claude_cache_above
            let req.messages[0]['content'][0]['cache_control'] = {"type": "ephemeral"}
        endif

        if system_msg isnot v:null
            let req['system'] = system_msg
        endif

        if has_key(params, 'thinking_tokens')
            let tokens = params['thinking_tokens']
            if has_key(params, 'on_sys_msg')
                call params.on_sys_msg(
                    \ 'info',
                    \ 'extended thinking with ' . tokens . ' token budget: ON')
            endif
            let req['thinking'] = {'type': 'enabled', 'budget_tokens': tokens}
        endif

        let req_id = self._req_id
        let self._req_id = self._req_id + 1
        let self._replies[req_id] = []


        if req.stream
            let self._builders[req_id] = vimqq#msg_builder#streaming(params)
            let job_conf = {
            \   'out_cb': {channel, d -> self._on_stream_out(d, params, req_id)},
            \   'err_cb': {channel, d -> self._on_error(d, params)},
            \   'close_cb': {channel -> self._on_stream_close(params)},
            \ }
        else
            let self._builders[req_id] = vimqq#msg_builder#assistant(params)
            let job_conf = {
            \   'out_cb': {channel, d -> self._on_out(d, params, req_id)},
            \   'err_cb': {channel, d -> self._on_error(d, params)},
            \   'close_cb': {channel -> self._on_close(params, req_id)}
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
            \ self._base_url . '/v1/messages',
            \ headers,
            \ json_req,
            \ job_conf)

    endfunction

    return api
endfunction
