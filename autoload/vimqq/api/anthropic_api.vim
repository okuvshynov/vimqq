if exists('g:autoloaded_vimqq_api_anthropic_module')
    finish
endif

let g:autoloaded_vimqq_api_anthropic_module = 1

let g:vqq_claude_api_key = get(g:, 'vqq_claude_api_key', $ANTHROPIC_API_KEY)

let s:RATE_LIMIT_WAIT_S  = 60
let s:CACHE_MARKER_LIMIT = 4

" config is unused for now
function! vimqq#api#anthropic_api#new(conf = {}) abort
    let api = {}

    let api._base_url = get(a:conf, 'base_url', 'https://api.anthropic.com')
    let api._req_id = 0
    let api._api_key = g:vqq_claude_api_key
    let api._builders = {}

    function! api._on_error(msg, params) dict
        call vimqq#log#error('job error')
    endfunction

    " Not calling any callback as we expect to act on data: [DONE]
    function! api._on_stream_close(params, req_id) dict
        let SysMessage = get(a:params, 'on_sys_msg', {l, m -> 0})
        call SysMessage('info', 'anthropic stream closed.')
        call self._cleanup_req_id(a:req_id)
    endfunction

    function! api._on_rate_limit(params) dict
        let SysMessage = get(a:params, 'on_sys_msg', {l, m -> 0})
        call SysMessage(
            \ 'warning',
            \ 'Reached rate limit. Waiting ' 
            \ . s:RATE_LIMIT_WAIT_S
            \ . ' seconds before retry'
        \ )

        call timer_start(
            \ s:RATE_LIMIT_WAIT_S * 1000,
            \ { timer_id -> self.chat(a:params)}
        \ )
    endfunction

    function! api._handle_error(error_json, params) dict
        let err = string(a:error_json['error'])
        if get(a:error_json['error'], 'type', '') ==# 'rate_limit_error'
            call self._on_rate_limit(a:params)
            return
        endif
        let SysMessage = get(a:params, 'on_sys_msg', {l, m -> 0})
        call SysMessage('error', err)
        call vimqq#log#error(err)
    endfunction

    function! api._on_stream_out(data, params, req_id) dict
        let SysMessage = get(a:params, 'on_sys_msg', {l, m -> 0})

        let builder = self._builders[a:req_id]

        for event in split(a:data, '\n')
            if event =~# '^event: '
                continue
            endif
            if event !~# '^data: '
                " Likely an error, let's try deserialize it
                try
                    let error_json = json_decode(event)
                    if error_json['type'] == 'error'
                        call self._handle_error(error_json, a:params)
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
                call builder.message_start(response['message'])
                continue
            endif

            if response['type'] ==# 'content_block_start'
                call builder.content_block_start(
                    \ response['index'],
                    \ response['content_block']
                \ )
                continue
            endif
            
            if response['type'] ==# 'content_block_delta'
                call builder.content_block_delta(
                    \ response['index'],
                    \ response['delta']
                \ )
                continue
            endif

            if response['type'] ==# 'content_block_stop'
                call builder.content_block_stop(response['index'])
                continue
            endif

            if response['type'] ==# 'message_delta'
                call builder.message_delta(get(response, 'usage', {}))
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
        call self._cleanup_req_id(a:req_id)
    endfunction
    
    function! api._cleanup_req_id(req_id) dict
        " Clean up resources for this req_id to avoid memory leaks
        if has_key(self._builders, a:req_id)
            unlet self._builders[a:req_id]
        endif
    endfunction

    function! api.chat(params) dict
        let req = vimqq#api#anthropic_adapter#run(a:params)

        " For our use-case we should probably just cache everything
        " We need to be consistent in what we mark with cache_control,
        " Let's only mark user/tool messages as cache
        let i = 0
        for message in req.messages
            if i >= s:CACHE_MARKER_LIMIT
                break
            endif
            if get(message, 'role', '') !=# 'user'
                continue
            endif
            let i = i + 1
            let message['content'][0]['cache_control'] = {'type': "ephemeral"}
        endfor

        let req_id = self._req_id
        let self._req_id = self._req_id + 1

        if req.stream
            let self._builders[req_id] = vimqq#api#anthropic_builder#streaming(a:params)
            let job_conf = {
            \   'out_cb': {channel, d -> self._on_stream_out(d, a:params, req_id)},
            \   'err_cb': {channel, d -> self._on_error(d, a:params)},
            \   'close_cb': {channel -> self._on_stream_close(a:params, req_id)},
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
