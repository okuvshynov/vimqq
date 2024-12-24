" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_llama_module')
    finish
endif

let g:autoloaded_vimqq_llama_module = 1

let s:healthcheck_ms = 10000

function vimqq#bots#llama#new(config = {}) abort
  " Start with base bot
  let l:llama = vimqq#bots#bot#new(extend(
      \ {'bot_name': 'Llama', 
      \  'system_prompt': 'You are a helpful assistant. Make sure to use all the provided context before producing an answer.'}, 
      \ a:config))
  
  let l:llama._conf.healthcheck_ms = get(a:config, 'healthcheck_ms', s:healthcheck_ms)

  let l:server = substitute(l:llama._conf.addr, '/*$', '', '')
  let l:llama._chat_endpoint   = l:server . '/v1/chat/completions'
  let l:llama._status_endpoint = l:server . '/health'

  " {{{ private:

  function l:llama._update_usage(response) dict
      " TODO: implement local token counter
  endfunction
  
  function l:llama._update_status(status) dict
      call vimqq#model#notify('bot_status', {'status' : a:status, 'bot': self})
  endfunction

  function l:llama._on_status_exit(exit_status) dict
      if a:exit_status != 0
          call self._update_status("unavailable")
      endif
      call timer_start(self._conf.healthcheck_ms, { -> self._get_status() })
  endfunction

  function l:llama._on_status_out(msg) dict
      try
          let l:status = json_decode(a:msg)
          if empty(l:status)
              call self._update_status("unavailable")
          else
              call self._update_status(l:status.status)
          endif
      " TODO: looks like json errors are different in vim/nvim.
      " Need to handle specific errors.
      catch
          call vimqq#log#info("Error decoding status: " . v:exception)
          call self._update_status("error")
      endtry
  endfunction

  function l:llama._get_status() dict
      if self._conf.healthcheck_ms < 0
          return
      endif
      let l:job_conf = {
            \ 'out_cb' : {channel, msg   -> self._on_status_out(msg)},
            \ 'exit_cb': {job_id, status -> self._on_status_exit(status)}
      \}
      call vimqq#platform#http_client#get(self._status_endpoint, ["--max-time", "5"], l:job_conf)
  endfunction

  function l:llama._send_query(req, job_conf) dict
      call vimqq#log#debug('sending query')
      let l:json_req = json_encode(a:req)
      let l:headers = {
          \ 'Content-Type': 'application/json'
      \ }
      return vimqq#platform#http_client#post(
          \ self._chat_endpoint,
          \ l:headers,
          \ l:json_req,
          \ a:job_conf)
  endfunction

  function! l:llama._on_stream_out(chat_id, msg) dict
      let l:messages = split(a:msg, '\n')
      for message in l:messages
          if message !~# '^data: '
              continue
          endif
          if message == 'data: [DONE]'
              call vimqq#model#notify('reply_done', {'chat_id': a:chat_id, 'bot': self})
              return
          endif
          let json_string = substitute(message, '^data: ', '', '')

          let response = json_decode(json_string)
          if has_key(response.choices[0].delta, 'content')
              let next_token = response.choices[0].delta.content
              call vimqq#model#notify('token_done', {'chat_id': a:chat_id, 'token': next_token})
          endif
      endfor
  endfunction

  function! l:llama._on_stream_close(chat_id)
      " Do nothing
  endfunction

  function! l:llama._on_err(chat_id, msg)
      call vimqq#log#error(join(a:msg, '\n'))
  endfunction

  function! l:llama._prepare_system_prompt() dict
      return {"role": "system", "content": self._conf.system_prompt}
  endfunction

  function! l:llama._prepare_request(messages) dict
      let req = {}
      let req.messages     = [self._prepare_system_prompt()] + vimqq#fmt#many(a:messages)
      let req.n_predict    = 0
      let req.stream       = v:true
      let req.cache_prompt = v:true
      return req
  endfunction

  " }}}

  " {{{ public:

  " warmup query to pre-fill the cache on the server.
  " We ask for 0 tokens and ignore the response.
  function! l:llama.send_warmup(messages) dict
      call vimqq#log#debug('Local: sending warmup')
      let req = self._prepare_request(a:messages)
      let req.n_predict = 0

      let l:job_conf = {
            \ 'close_cb': {channel -> vimqq#model#notify('warmup_done', {'bot': self})}
      \ }
      return self._send_query(req, l:job_conf)
  endfunction

  function! l:llama.send_chat(chat_id, messages) dict
      let req = self._prepare_request(a:messages)
      let req.n_predict = self._conf.max_tokens

      let l:job_conf = {
            \ 'out_cb'  : {channel, msg -> self._on_stream_out(a:chat_id, msg)}, 
            \ 'err_cb'  : {channel, msg -> self._on_err(a:chat_id, msg)},
            \ 'close_cb': {channel      -> self._on_stream_close(a:chat_id)}
      \ }

      return self._send_query(req, l:job_conf)
  endfunction

  " Following interface required by bot.vim for title generation
  function! l:llama.get_req(user_content) dict
      let req = {}
      let req.messages = [self._prepare_system_prompt()] + [{"role": "user", "content": a:user_content}]
      let req.n_predict = self._conf.title_tokens
      let req.stream = v:false
      let req.cache_prompt = v:true
      return req
  endfunction

  function! l:llama.get_response_text(response) dict
      return a:response.choices[0].message.content
  endfunction

  " }}}
  
  call l:llama._get_status()
  return l:llama

endfunction
