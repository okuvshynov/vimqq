if exists('g:autoloaded_vimqq_api_llama_module')
    finish
endif

let g:autoloaded_vimqq_api_llama_module = 1

function! vimqq#api#llama_api#new(conf) abort
    let api = {}

    let api._endpoint = a:conf.endpoint
    " stores partial responses
    let api._req_id = 0
    let api._jinja = get(a:conf, 'jinja', v:false)
    let api._builders = {}

    function! api._on_stream_out(msg, params, req_id) dict
        let builder = self._builders[a:req_id]
        let messages = split(a:msg, '\n')
        for message in messages
            call vimqq#log#debug(message)
            if message !~# '^data: '
                call vimqq#log#warning('Unexpected reply: ' . message)
                continue
            endif
            if message ==# 'data: [DONE]'
                call builder.message_stop()
                return
            endif
            let json_string = substitute(message, '^data: ', '', '')
            let response = json_decode(json_string)
            call builder.delta(response)
        endfor
    endfunction

    " Not calling any callback as we expect to act on data: [DONE]
    " However, we might need to do that to handle any errors?
    function! api._on_stream_close(params) dict
        call vimqq#log#debug('llama.cpp stream closed')
    endfunction

    function! api._on_out(msg, params, req_id) dict
        let builder = self._builders[a:req_id]
        call builder.part(a:msg)
    endfunction

    function! api._on_close(params, req_id) dict
        let builder = self._builders[a:req_id]
        call builder.close()
    endfunction

    function! api._on_error(msg, params) dict
        call vimqq#log#error('llama_api: error')
    endfunction

    function! api.chat(params) dict
        let SysMessage = get(a:params, 'on_sys_msg', {l, m -> 0})
        let req = {
        \   'messages': get(a:params, 'messages', []),
        \   'n_predict': get(a:params, 'max_tokens', 1024),
        \   'cache_prompt': get(a:params, 'cache_prompt', v:true)
        \ }

        " llama.cpp with jinja needs 
        "   content : 'hello', not 
        "   content : [{type: text, text: 'hello'}] format
        if self._jinja
            " TODO: Modifies inplace, let's maybe return it instead
            call vimqq#api#llama_cpp_adapter#jinja(req)
        endif

        let req_id = self._req_id
        let self._req_id = self._req_id + 1

        let stream = get(a:params, 'stream', v:false)

        if has_key(a:params, 'tools')
            if !self._jinja
                let warning = 'llama_api: using tools with llama.cpp requires jinja templates. Skipping tools.'
                call vimqq#log#warning(warning)
                call SysMessage('warning', warning)
            else
                " llama.cpp server doesn't support streaming with tools
                if stream
                    let warning = 'llama_api: not using streaming as it is not compatible with tools'
                    call vimqq#log#warning(warning)
                    call SysMessage('warning', warning)
                endif
                let stream = v:false
                let req['tools'] = a:params['tools']
            endif
        endif
        
        let req['stream'] = stream

        if stream
            let self._builders[req_id] = vimqq#api#llama_cpp_builder#streaming(a:params)
            let job_conf = {
            \   'out_cb': {channel, msg -> self._on_stream_out(msg, a:params, req_id)},
            \   'err_cb': {channel, msg -> self._on_error(msg, a:params)},
            \   'close_cb': {channel -> self._on_stream_close(a:params)},
            \ }
        else
            let self._builders[req_id] = vimqq#api#llama_cpp_builder#plain(a:params)
            let job_conf = {
            \   'out_cb': {channel, msg -> self._on_out(msg, a:params, req_id)},
            \   'err_cb': {channel, msg -> self._on_error(msg, a:params, req_id)},
            \   'close_cb': {channel -> self._on_close(a:params, req_id)}
            \ }
        endif

        let json_req = json_encode(req)
        let headers = {
            \ 'Content-Type': 'application/json'
        \ }
        return vimqq#platform#http#post(
            \ self._endpoint,
            \ headers,
            \ json_req,
            \ job_conf)
    endfunction

    return api
endfunction
