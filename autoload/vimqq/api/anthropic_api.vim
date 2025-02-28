if exists('g:autoloaded_vimqq_api_anthropic_module')
    finish
endif

let g:autoloaded_vimqq_api_anthropic_module = 1

let g:vqq_claude_api_key = get(g:, 'vqq_claude_api_key', $ANTHROPIC_API_KEY)
let g:vqq_claude_cache_above = get(g:, 'vqq_claude_cache_above', 5000)

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

    function! api.chat(params) dict
        let req = vimqq#api#anthropic_adapter#run(a:params)
        let messages = req.messages

        let first_message_json = json_encode(messages[0])
        if len(first_message_json) > g:vqq_claude_cache_above
            let req.messages[0]['content'][0]['cache_control'] = {"type": "ephemeral"}
        endif

        let req_id = self._req_id
        let self._req_id = self._req_id + 1
        let self._replies[req_id] = []

        if req.stream
            let self._builders[req_id] = vimqq#api#anthropic_builder#streaming(a:params)
            let job_conf = {
            \   'out_cb': {channel, d -> self._on_stream_out(d, a:params, req_id)},
            \   'err_cb': {channel, d -> self._on_error(d, a:params)},
            \   'close_cb': {channel -> self._on_stream_close(a:params)},
            \ }
        else
            let self._builders[req_id] = vimqq#api#anthropic_builder#plain(a:params)
            let job_conf = {
            \   'out_cb': {channel, d -> self._on_out(d, a:params, req_id)},
            \   'err_cb': {channel, d -> self._on_error(d, a:params)},
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
            \ self._base_url . '/v1/messages',
            \ headers,
            \ json_req,
            \ job_conf)

    endfunction

    return api
endfunction
