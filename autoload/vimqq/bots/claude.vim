" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_claude_module')
    finish
endif

let g:autoloaded_vimqq_claude_module = 1

" API key for anthropic
let g:vqq_claude_api_key = get(g:, 'vqq_claude_api_key', $ANTHROPIC_API_KEY)

" TODO: handling errors 
function! vimqq#bots#claude#new(config = {}) abort
    " Start with base bot
    let l:claude = vimqq#bots#bot#new(extend(
        \ {'bot_name': 'Claude'}, 
        \ a:config))
    
    let l:claude._api_key = g:vqq_claude_api_key

    " {{{ private:
    
    function! l:claude.get_usage(response) dict
        let usage = {}
        let usage['in'] = get(a:response.usage, 'input_tokens', 0)
        let usage['out'] = get(a:response.usage, 'output_tokens', 0)
        return usage
    endfunction

    function! l:claude._on_stream_out(chat_id, msg) dict
      let l:messages = split(a:msg, '\n')
      for message in l:messages
          if message !~# '^data: '
              continue
          endif
          let json_string = substitute(message, '^data: ', '', '')
          let response = json_decode(json_string)

          if response['type'] == 'message_start'
              call self._update_usage(response.message)
              return
          endif
          if response['type'] == 'message_stop'
              call vimqq#model#notify('reply_done', {'chat_id': a:chat_id, 'bot': self})
              return
          endif
          if response['type'] == 'message_delta'
              call self._update_usage(response)
              return
          endif
          if response['type'] == 'content_block_delta'
              let next_token = response.delta.text
              call vimqq#model#notify('chunk_done', {'chat_id': a:chat_id, 'chunk': next_token})
          endif
      endfor
    endfunction

    function! l:claude._on_stream_close(chat_id)
      " Do nothing
    endfunction

    function! l:claude._on_err(chat_id, msg) dict
        call vimqq#log#error('claude error: ' . a:msg)
    endfunction

    function! l:claude._send_query(req, job_conf) dict
        let l:json_req = json_encode(a:req)
        let l:headers = {
            \ 'Content-Type': 'application/json',
            \ 'x-api-key': self._api_key,
            \ 'anthropic-version': '2023-06-01'
        \ }
        return vimqq#platform#http_client#post(
            \ 'https://api.anthropic.com/v1/messages',
            \ l:headers,
            \ l:json_req,
            \ a:job_conf)
    endfunction

    function! l:claude._prepare_request(messages) dict
        let req = {}
        let req.model      = self._conf.model
        let req.system     = self._conf.system_prompt
        let req.messages   = self._format_messages(a:messages)
        let req.max_tokens = self._conf.max_tokens
        let req.stream     = v:true
        return req
    endfunction

    " }}}

    " {{{ public:

    function! l:claude.send_warmup(messages) dict
      " do nothing, as Claude API is stateless
      " TODO: this is not true anymore, we can cache now
      " Figure out a right way to do it, we probably don't want to cache every
      " query
    endfunction

    function! l:claude.send_chat(chat_id, messages) dict
        let req = self._prepare_request(a:messages)
        let self._reply_by_id[a:chat_id] = []

        let l:job_conf = {
              \ 'out_cb'  : {channel, msg -> self._on_stream_out(a:chat_id, msg)}, 
              \ 'err_cb'  : {channel, msg -> self._on_err(a:chat_id, msg)},
              \ 'close_cb': {channel      -> self._on_stream_close(a:chat_id)}
        \ }

        return self._send_query(req, l:job_conf)
    endfunction

    " ask for a title we'll use. Uses first message in a chat
    function! l:claude.get_req(user_content) dict
        let req = {}
        let req.messages   = [{"role": "user", "content": a:user_content}]
        let req.max_tokens = self._conf.title_tokens
        let req.model      = self._conf.model
        let req.system     = self._conf.system_prompt
        return req
    endfunction

    function! l:claude.get_response_text(response) dict
        return a:response.content[0].text
    endfunction

    " }}}

    return l:claude
endfunction
