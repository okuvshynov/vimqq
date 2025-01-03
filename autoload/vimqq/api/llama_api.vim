if exists('g:autoloaded_vimqq_api_llama_module')
    finish
endif

let g:autoloaded_vimqq_api_llama_module = 1

function! vimqq#api#llama_api#new(endpoint) abort
    let l:api = {}

    let l:api._endpoint = a:endpoint
    " stores partial responses
    let l:api._replies = {}
    let l:api._req_id = 0

    function! l:api._on_stream_out(msg, params) dict
      let l:messages = split(a:msg, '\n')
      for message in l:messages
          if message !~# '^data: '
              call vimqq#log#info('Unexpected reply: ' . message)
              continue
          endif
          if message == 'data: [DONE]'
              call a:params.on_complete(a:params)
              return
          endif
          let json_string = substitute(message, '^data: ', '', '')
          let response = json_decode(json_string)
          if has_key(response.choices[0].delta, 'content')
              let chunk = response.choices[0].delta.content
              call a:params.on_chunk(a:params, chunk)
          endif
      endfor
    endfunction

    " Not calling any callback as we expect to act on data: [DONE]
    function! l:api._on_stream_close(params) dict
        call vimqq#log#info('llama stream closed.')
    endfunction

    function! l:api._on_out(msg, params, req_id) dict
        if !has_key(self._replies, a:req_id)
            call vimqq#log#error('llama_api: reply for non-existent request: ' . a:req_id)
            return
        endif
        call add(self._replies[a:req_id], a:msg)
    endfunction

    function! l:api._on_close(params, req_id) dict
        if !has_key(self._replies, a:req_id)
            call vimqq#log#error('llama_api: reply for non-existent request: ' . a:req_id)
            return
        endif
        let l:response = join(self._replies[a:req_id], '\n')
        let l:response = json_decode(l:response)
        if type(l:response) == type({}) &&
                \ has_key(l:response, 'choices') && 
                \ !empty(l:response.choices) && 
                \ has_key(l:response.choices[0], 'message')
            let l:message  = l:response.choices[0].message.content
            if has_key(a:params, 'on_chunk')
                call a:params.on_chunk(a:params, l:message)
            endif
            if has_key(a:params, 'on_complete')
                call a:params.on_complete(a:params)
            endif
        else
            " TODO: still need to close/complete
            call vimqq#log#error('llama_api: Unable to process response')
            call vimqq#log#error(json_encode(l:response))
        endif
    endfunction

    function! l:api._on_error(msg, params) dict
        call vimqq#log#error('API error')
    endfunction

    function! l:api.chat(params) dict
        let req = {
        \   'messages': get(a:params, 'messages', []),
        \   'n_predict': get(a:params, 'max_tokens', 1024),
        \   'stream': get(a:params, 'stream', v:false),
        \   'cache_prompt': get(a:params, 'cache_prompt', v:true)
        \ }

        let req_id = self._req_id
        let self._req_id = self._req_id + 1
        let self._replies[req_id] = []

        if req.stream
            let l:job_conf = {
            \   'out_cb': {channel, msg -> self._on_stream_out(msg, a:params)},
            \   'err_cb': {channel, msg -> self._on_error(msg, a:params)},
            \   'close_cb': {channel -> self._on_stream_close(a:params)},
            \ }
        else
            let l:job_conf = {
            \   'out_cb': {channel, msg -> self._on_out(msg, a:params, req_id)},
            \   'err_cb': {channel, msg -> self._on_error(msg, a:params, req_id)},
            \   'close_cb': {channel -> self._on_close(a:params, req_id)}
            \ }
        endif

        let l:json_req = json_encode(req)
        let l:headers = {
            \ 'Content-Type': 'application/json'
        \ }
        return vimqq#platform#http#post(
            \ self._endpoint,
            \ l:headers,
            \ l:json_req,
            \ l:job_conf)
    endfunction

    return l:api

endfunction
