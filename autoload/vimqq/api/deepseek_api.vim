if exists('g:autoloaded_vimqq_api_deepseek_module')
    finish
endif

let g:autoloaded_vimqq_api_deepseek_module = 1

let g:vqq_deepseek_api_key = get(g:, 'vqq_deepseek_api_key', $DEEPSEEK_API_KEY)

" conf is unused for now
function! vimqq#api#deepseek_api#new(conf) abort
    let api = {}

    " stores partial responses
    let api._replies = {}
    let api._tool_uses = {}
    let api._req_id = 0
    let api._api_key = g:vqq_deepseek_api_key

    function! api._on_stream_out(msg, params, req_id) dict
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
            " deepseek API returns streamed tools like this:
            "  - first message is function name
            "  - next messages are arguments
            "
            "  How does it work with many calls?
            if has_key(response.choices[0].delta, 'tool_calls')
                let tool_calls = response.choices[0].delta.tool_calls
                if has_key(self._tool_uses, a:req_id)
                    let args_delta = tool_calls[0]['function'].arguments
                    let self._tool_uses[a:req_id].input = self._tool_uses[a:req_id].input . args_delta
                else
                    let self._tool_uses[a:req_id] = {
                        \ 'name': tool_calls[0]['function'].name,
                        \ 'input': tool_calls[0]['function'].arguments,
                        \ 'id': tool_calls[0].id
                    \}
                endif
            endif

            if response.choices[0].finish_reason ==# 'tool_calls'
                if has_key(self._tool_uses, a:req_id)
                    let self._tool_uses[a:req_id]['input'] = json_decode(self._tool_uses[a:req_id]['input'])
                    call a:params.on_tool_use(self._tool_uses[a:req_id])
                else
                    call vimqq#log#error('deepseek api: trying to use tools but none were passed')
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
        let tools = get(a:params, 'tools', [])
        let req = {
        \   'messages': get(a:params, 'messages', []),
        \   'model': a:params.model,
        \   'max_tokens': get(a:params, 'max_tokens', 1024),
        \   'stream': get(a:params, 'stream', v:false),
        \ }

        if len(tools) > 1
            let req.tools = tools
        endif


        for message in req.messages
            if type(message.content) == type([])
                try
                    let content = message.content[0]

                    if content['type'] ==# 'tool_use'
                        let message.tool_calls = [{
                           \ 'id': content['id'],
                           \ 'type': 'function',
                           \ 'function': {
                           \    'name': content['name'],
                           \    'arguments': json_encode(content['input'])
                           \ }
                        \ }]
                        let message.content = ""
                        call vimqq#log#debug('adapted tool call: ' . string(message))
                    endif

                    if content['type'] ==# 'tool_result'
                        let message['role'] = 'tool'
                        let message['tool_call_id'] = content['tool_use_id']
                        let message['content'] = content.content
                        call vimqq#log#debug('adapted tool result: ' . string(message))
                    endif
                catch
                    call vimqq#log#error('llama_api: error adapting: ' . string(message.content))
                endtry
            endif
        endfor

        let req_id = self._req_id
        let self._req_id = self._req_id + 1
        let self._replies[req_id] = []

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
