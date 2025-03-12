if exists('g:autoloaded_vimqq_api_mock_module')
    finish
endif

let g:autoloaded_vimqq_api_mock_module = 1

function! vimqq#api#mock_api#new(conf) abort
    let api = {}

    " No actual endpoint needed for mock API
    let api._req_id = 0
    let api._builders = {}

    " For streaming, we'll break the response into multiple chunks
    function! api._on_stream_out(msg, params, req_id) dict
        let builder = self._builders[a:req_id]
        
        " In a real streaming response, we'd get multiple data lines
        " Here we're simulating that by processing each character separately
        for char in split(a:msg, '\zs')
            " Format like a real SSE message
            let message = 'data: {"choices":[{"delta":{"content":"' . char . '"}}]}'
            
            if message !~# '^data: '
                call vimqq#log#warning('Unexpected reply: ' . message)
                continue
            endif
            
            let json_string = substitute(message, '^data: ', '', '')
            let response = json_decode(json_string)
            call builder.delta(response)
        endfor
        
        " Signal the end of the stream
        call builder.message_stop()
    endfunction

    function! api._on_stream_close(params) dict
        call vimqq#log#debug('mock_api stream closed')
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
        call vimqq#log#error('mock_api: error')
    endfunction

    function! api.chat(params) dict
        let SysMessage = get(a:params, 'on_sys_msg', {l, m -> 0})
        
        " Calculate the length of the conversation
        let messages = get(a:params, 'messages', [])
        let conv_length = 0
        
        " Count the total characters in all messages
        for msg in messages
            if has_key(msg, 'content')
                if type(msg.content) == type([])
                    " Handle array of content objects
                    for content_part in msg.content
                        if has_key(content_part, 'text')
                            let conv_length += len(content_part.text)
                        endif
                    endfor
                elseif type(msg.content) == type("")
                    " Handle simple string content
                    let conv_length += len(msg.content)
                endif
            endif
        endfor
        
        " Create response string - conversation length
        let response_text = "The conversation length is " . conv_length . " characters."
        let req_id = self._req_id
        let self._req_id = self._req_id + 1
        
        let stream = get(a:params, 'stream', v:false)
        
        if stream
            let self._builders[req_id] = vimqq#api#llama_cpp_builder#streaming(a:params)
            
            " For streaming, we'll simulate delay by using a job
            let job_conf = {
            \   'out_cb': {channel, msg -> self._on_stream_out(response_text, a:params, req_id)},
            \   'err_cb': {channel, msg -> self._on_error(msg, a:params)},
            \   'close_cb': {channel -> self._on_stream_close(a:params)},
            \ }
            
            " Echo the message to simulate a command that returns output
            return vimqq#platform#jobs#start('echo "mock_streaming"', job_conf)
        else
            let self._builders[req_id] = vimqq#api#llama_cpp_builder#plain(a:params)
            
            " Format the response as JSON like a real API would
            let json_response = '{"choices":[{"message":{"content":"' . response_text . '"}}]}'
            
            let job_conf = {
            \   'out_cb': {channel, msg -> self._on_out(json_response, a:params, req_id)},
            \   'err_cb': {channel, msg -> self._on_error(msg, a:params, req_id)},
            \   'close_cb': {channel -> self._on_close(a:params, req_id)}
            \ }
            
            " Echo the message to simulate a command that returns output
            return vimqq#platform#jobs#start('echo "mock_nonstreaming"', job_conf)
        endif
    endfunction

    return api
endfunction
