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
  \ 'system_prompt'  : 'You are a helpful assistant.'
\ }

" TODO: handling errors 
function! vimqq#claude#new(config = {}) abort
    let l:claude = {}
    call extend(l:claude, vimqq#base#new())

    let l:claude._conf = deepcopy(s:default_conf)
    call extend(l:claude._conf, a:config)

    let l:claude._api_key = g:vqq_claude_api_key

    let l:claude._reply_by_id = {}
    let l:claude._title_reply_by_id = {}

    let l:claude._usage = {'in': 0, 'out': 0}

    " {{{ private:

    function! l:claude._update_usage(usage) dict
        let self._usage['in']  += a:usage['input_tokens']
        let self._usage['out'] += a:usage['output_tokens']

        let msg = self._usage['in'] . " in, " . self._usage['out'] . " out"

        call self.call_cb('status_cb', msg, self)
    endfunction

    function! l:claude._on_title_out(chat_id, msg) dict
        call add(self._title_reply_by_id[a:chat_id], a:msg)
    endfunction

    function l:claude._on_title_close(chat_id) dict
        let l:response = json_decode(join(self._title_reply_by_id[a:chat_id], '\n'))
        let l:title  = l:response.content[0].text
        call self._update_usage(l:response.usage)
        call self.call_cb('title_done_cb', a:chat_id, title)
    endfunction

    function! l:claude._on_out(chat_id, msg) dict
        call add(self._reply_by_id[a:chat_id], a:msg)
    endfunction

    function! l:claude._on_err(chat_id, msg) dict
        " TODO logging (or status callback?)
    endfunction

    function l:claude._on_close(chat_id) dict
        let l:response = json_decode(join(self._reply_by_id[a:chat_id], '\n'))
        let l:message  = l:response.content[0].text
        call self._update_usage(l:response.usage)
        " we pretend it's one huge update
        call self.call_cb('token_cb', a:chat_id, l:message)
        " and immediately done
        call self.call_cb('stream_done_cb', a:chat_id, self)
    endfunction

    function! l:claude._send_query(req, job_conf) dict
        let l:json_req  = json_encode(a:req)
        let l:json_req  = substitute(l:json_req, "'", "'\\\\''", "g")

        let l:curl_cmd  = "curl -s -X POST 'https://api.anthropic.com/v1/messages'"
        let l:curl_cmd .= " -H 'Content-Type: application/json'"
        let l:curl_cmd .= " -H 'x-api-key: " . self._api_key . "'"
        let l:curl_cmd .= " -H 'anthropic-version: 2023-06-01'"
        let l:curl_cmd .= " -d '" . l:json_req . "'"

        call vimqq#utils#keep_job(job_start(['/bin/sh', '-c', l:curl_cmd], a:job_conf))
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

    function! l:claude.send_warmup(chat_id, messages) dict
      " we do nothing, as Claude API is stateless, no point in 
      " preparing anything
    endfunction

    function! l:claude.send_chat(chat_id, messages) dict
        let req = {}
        let req.model      = self._conf.model
        let req.system     = self._conf.system_prompt
        let req.messages   = self._format_messages(a:messages)
        let req.max_tokens = self._conf.max_tokens
        let self._reply_by_id[a:chat_id] = []

        let l:job_conf = {
              \ 'out_cb'  : {channel, msg -> self._on_out(a:chat_id, msg)}, 
              \ 'err_cb'  : {channel, msg -> self._on_err(a:chat_id, msg)},
              \ 'close_cb': {channel      -> self._on_close(a:chat_id)}
        \ }

        call self._send_query(req, l:job_conf)
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

        call self._send_query(req, l:job_conf)
    endfunction

    " }}}

    return l:claude
endfunction
