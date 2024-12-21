" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_claude_module')
    finish
endif

let g:autoloaded_vimqq_claude_module = 1

" API key for anthropic
let g:vqq_claude_api_key = get(g:, 'vqq_claude_api_key', $ANTHROPIC_API_KEY)

let s:default_conf = {
  \ 'title_tokens'   : 16,
  \ 'max_tokens'     : 1024,
  \ 'bot_name'       : 'Claude',
  \ 'system_prompt'  : 'You are a helpful assistant.',
  \ 'do_autowarm'    : v:false
\ }

" TODO: handling errors 
function! vimqq#bots#claude#new(config = {}) abort
    let l:claude = {}

    let l:claude._conf = deepcopy(s:default_conf)
    call extend(l:claude._conf, a:config)

    let l:claude._api_key = g:vqq_claude_api_key

    let l:claude._reply_by_id = {}
    let l:claude._title_reply_by_id = {}

    let l:claude._usage = {'in': 0, 'out': 0}

    " {{{ private:

    function! l:claude._update_usage(usage) dict
        let self._usage['in']  += get(a:usage, 'input_tokens', 0)
        let self._usage['out'] += get(a:usage, 'output_tokens', 0)

        let msg = self._usage['in'] . " in, " . self._usage['out'] . " out"

        call vimqq#log#info("claude " . self.name() . " total usage: " . msg)

        call vimqq#model#notify('bot_status', {'status' : msg, 'bot': self})
    endfunction

    function! l:claude._on_title_out(chat_id, msg) dict
        call add(self._title_reply_by_id[a:chat_id], a:msg)
    endfunction

    function l:claude._on_title_close(chat_id) dict
        let l:response = json_decode(join(self._title_reply_by_id[a:chat_id], '\n'))
        let l:title  = l:response.content[0].text
        call self._update_usage(l:response.usage)
        call vimqq#model#notify('title_done', {'chat_id' : a:chat_id, 'title': title})
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
                call self._update_usage(response.message.usage)
                return
              endif
              if response['type'] == 'message_stop'
                  call vimqq#model#notify('reply_done', {'chat_id': a:chat_id, 'bot': self})
                  return
              endif
              if response['type'] == 'message_delta'
                call self._update_usage(response.usage)
                return
              endif
              if response['type'] == 'content_block_delta'
                  let next_token = response.delta.text
                  call vimqq#model#notify('token_done', {'chat_id': a:chat_id, 'token': next_token})
              endif
          endfor
      endfunction

  function! l:claude._on_stream_close(chat_id)
      " Do nothing
  endfunction

    function! l:claude._on_out(chat_id, msg) dict
        call add(self._reply_by_id[a:chat_id], a:msg)
    endfunction

    function! l:claude._on_err(chat_id, msg) dict
        call vimqq#log#error('claude error: ' . a:msg)
    endfunction

    function l:claude._on_close(chat_id) dict
        let l:response = json_decode(join(self._reply_by_id[a:chat_id], '\n'))
        if has_key(l:response, 'content') && !empty(l:response.content) && has_key(l:response.content[0], 'text')
            let l:message  = l:response.content[0].text
            call self._update_usage(l:response.usage)
            " we pretend it's one huge update
            call vimqq#model#notify('token_done', {'chat_id': a:chat_id, 'token': l:message})
            " and immediately done
            call vimqq#model#notify('reply_done', {'chat_id': a:chat_id, 'bot': self})
        else
            call vimqq#log#error('Unable to process response')
            call vimqq#log#error(json_encode(l:response))
            " TODO: still need to mark query as done
        endif
    endfunction

    function! l:claude._send_query(req, job_conf) dict
        let l:json_req  = json_encode(a:req)
        let l:json_req  = substitute(l:json_req, "'", "'\\\\''", "g")

        let l:curl_cmd  = "curl -s -X POST 'https://api.anthropic.com/v1/messages'"
        let l:curl_cmd .= " -H 'Content-Type: application/json'"
        let l:curl_cmd .= " -H 'x-api-key: " . self._api_key . "'"
        let l:curl_cmd .= " -H 'anthropic-version: 2023-06-01'"
        let l:curl_cmd .= " -d '" . l:json_req . "'"

        return vimqq#platform#jobs#start(['/bin/sh', '-c', l:curl_cmd], a:job_conf)
    endfunction

    function! l:claude._format_messages(messages) dict
        let l:res = []
        for msg in vimqq#fmt#many(a:messages)
            " Skipping empty messages
            if !empty(msg.content)
                call add (l:res, {'role': msg.role, 'content': msg.content})
            endif
        endfor
        return l:res
    endfunction

    " }}}

    " {{{ public:

    function! l:claude.name() dict
        return self._conf.bot_name
    endfunction

    function! l:claude.do_autowarm() dict
        return self._conf.do_autowarm
    endfunction

    function! l:claude.send_warmup(messages) dict
      " do nothing, as Claude API is stateless
      " TODO: this is not true anymore, we can cache now
      " Figure out a right way to do it, we probably don't want to cache every
      " query
    endfunction

    function! l:claude.send_chat(chat_id, messages) dict
        let req = {}
        let req.model      = self._conf.model
        let req.system     = self._conf.system_prompt
        let req.messages   = self._format_messages(a:messages)
        let req.max_tokens = self._conf.max_tokens
        let req.stream     = v:true
        let self._reply_by_id[a:chat_id] = []

        let l:job_conf = {
              \ 'out_cb'  : {channel, msg -> self._on_stream_out(a:chat_id, msg)}, 
              \ 'err_cb'  : {channel, msg -> self._on_err(a:chat_id, msg)},
              \ 'close_cb': {channel      -> self._on_stream_close(a:chat_id)}
        \ }

        return self._send_query(req, l:job_conf)
    endfunction

    " ask for a title we'll use. Uses first message in a chat
    function! l:claude.send_gen_title(chat_id, message) dict
        let req = {}
        let l:message_text = vimqq#fmt#content(a:message)
        " TODO: make configurable and remove duplicate code with llama.vim
        let prompt = "Write a title with a few words summarizing the following paragraph. Reply only with title itself. Use no quotes around it.\n\n"
        let req.messages   = [{"role": "user", "content": prompt . l:message_text}]
        let req.max_tokens = self._conf.title_tokens
        let req.model      = self._conf.model
        let req.system     = self._conf.system_prompt

        let self._title_reply_by_id[a:chat_id] = []

        let l:job_conf = {
              \ 'out_cb'  : {channel, msg -> self._on_title_out(a:chat_id, msg)},
              \ 'close_cb': {channel      -> self._on_title_close(a:chat_id)}
        \ }

        return self._send_query(req, l:job_conf)
    endfunction

    " }}}

    return l:claude
endfunction
