" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_llama_module')
    finish
endif

let g:autoloaded_vimqq_llama_module = 1

let s:default_conf = {
  \ 'healthcheck_ms' : 10000,
  \ 'title_tokens'   : 16,
  \ 'max_tokens'     : 1024,
  \ 'bot_name'       : 'Llama',
  \ 'system_prompt'  : 'You are a helpful assistant. Make sure to use all the provided context before producing an answer.'
\ }

function vimqq#bots#llama#new(config = {}) abort
  let l:llama = {} 
  
  call extend(l:llama, vimqq#base#new())

  let l:llama._conf = deepcopy(s:default_conf)
  call extend(l:llama._conf, a:config)

  let l:server = substitute(l:llama._conf.addr, '/*$', '', '')
  let l:llama._chat_endpoint   = l:server . '/v1/chat/completions'
  let l:llama._status_endpoint = l:server . '/health'

  " {{{ private:
  
  function l:llama._update_status(status)
      call self.call_cb('status_cb', a:status, self)
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
      catch /E491:/
          " Handle JSON decoding error
          call vimqq#log#info("Error decoding status: " . v:exception)
          call self._update_status("error")
      endtry
  endfunction

  function l:llama._get_status() dict
      if self._conf.healthcheck_ms < 0
          return
      endif
      let l:curl_cmd = ["curl", "--max-time", "5", self._status_endpoint]
      let l:job_conf = {
            \ 'out_cb' : {channel, msg   -> self._on_status_out(msg)},
            \ 'exit_cb': {job_id, status -> self._on_status_exit(status)}
      \}

      call vimqq#jobs#start(l:curl_cmd, l:job_conf)
  endfunction

  function l:llama._send_chat_query(req, job_conf) dict
      let l:json_req  = json_encode(a:req)
      let l:json_req  = substitute(l:json_req, "'", "'\\\\''", "g")

      let l:curl_cmd  = "curl --no-buffer -s -X POST '" . self._chat_endpoint . "'"
      let l:curl_cmd .= " -H 'Content-Type: application/json'"
      let l:curl_cmd .= " -d '" . l:json_req . "'"

      return vimqq#jobs#start(['/bin/sh', '-c', l:curl_cmd], a:job_conf)
  endfunction

  function! l:llama._on_stream_out(chat_id, msg) dict
      let l:messages = split(a:msg, '\n')
      for message in l:messages
          if message !~# '^data: '
              continue
          endif
          let json_string = substitute(message, '^data: ', '', '')

          let response = json_decode(json_string)
          if has_key(response.choices[0].delta, 'content')
              let next_token = response.choices[0].delta.content
              call self.call_cb('token_cb', a:chat_id, next_token)
          endif
      endfor
  endfunction

  function! l:llama._on_stream_close(chat_id)
      call self.call_cb('stream_done_cb', a:chat_id, self)
  endfunction

  function! l:llama._on_err(chat_id, msg)
      call vimqq#log#error(join(a:msg, '\n'))
  endfunction

  function! l:llama._on_title_out(chat_id, msg)
      let json_string = substitute(a:msg, '^data: ', '', '')

      let response = json_decode(json_string)
      if has_key(response.choices[0].message, 'content')
          let title = response.choices[0].message.content
          call self.call_cb('title_done_cb', a:chat_id, title)
      endif
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
      let req = self._prepare_request(a:messages)
      let req.n_predict = 0

      let l:job_conf = {
            \ 'close_cb': {channel -> self.call_cb('warmup_done_cb')}
      \ }
      return self._send_chat_query(req, l:job_conf)
  endfunction

  function! l:llama.send_chat(chat_id, messages) dict
      let req = self._prepare_request(a:messages)
      let req.n_predict = self._conf.max_tokens

      let l:job_conf = {
            \ 'out_cb'  : {channel, msg -> self._on_stream_out(a:chat_id, msg)}, 
            \ 'err_cb'  : {channel, msg -> self._on_err(a:chat_id, msg)},
            \ 'close_cb': {channel      -> self._on_stream_close(a:chat_id)}
      \ }

      return self._send_chat_query(req, l:job_conf)
  endfunction

  " ask for a title we'll use. Uses first message in a chat
  " TODO: this pollutes the kv cache for next messages.
  function! l:llama.send_gen_title(chat_id, message) dict
      let req = {}
      let l:message_text = vimqq#fmt#content(a:message)
      let l:prompt = "Do not answer question above. Instead, write title with a few words summarizing the text. Reply only with title itself. Use no quotes around it.\n\n"
      let req.messages  = [self._prepare_system_prompt()] + [{"role": "user", "content": l:message_text . l:prompt}]
      let req.n_predict    = self._conf.title_tokens
      let req.stream       = v:false
      let req.cache_prompt = v:true

      let l:job_conf = {
            \ 'out_cb': {channel, msg -> self._on_title_out(a:chat_id, msg)}
      \ }

      return self._send_chat_query(req, l:job_conf)
  endfunction

  function! l:llama.name() dict
      return self._conf.bot_name
  endfunction

  " }}}
  
  call l:llama._get_status()
  return l:llama

endfunction
