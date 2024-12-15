" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_mistral_module')
    finish
endif

let g:autoloaded_vimqq_mistral_module = 1

" API key for mistral
let g:vqq_mistral_api_key = get(g:, 'vqq_mistral_api_key', $MISTRAL_API_KEY)

let s:default_conf = {
  \ 'title_tokens'   : 16,
  \ 'max_tokens'     : 1024,
  \ 'bot_name'       : 'mistral',
  \ 'system_prompt'  : 'You are a helpful assistant.',
  \ 'do_autowarm'    : v:false
\ }

function! vimqq#bots#mistral#new(config = {}) abort
    let l:mistral_bot = {}
    call extend(l:mistral_bot, vimqq#base#new())

    let l:mistral_bot._conf = deepcopy(s:default_conf)
    call extend(l:mistral_bot._conf, a:config)

    let l:mistral_bot._api_key = g:vqq_mistral_api_key

    let l:mistral_bot._reply_by_id = {}
    let l:mistral_bot._title_reply_by_id = {}

    let l:mistral_bot._usage = {'in': 0, 'out': 0}

    " {{{ private:

    function! l:mistral_bot._update_usage(usage) dict
        let self._usage['in']  += a:usage['prompt_tokens']
        let self._usage['out'] += a:usage['completion_tokens']
        call vimqq#metrics#inc('mistral.' . self._conf.model . '.tokens_in', a:usage['prompt_tokens'])
        call vimqq#metrics#inc('mistral.' . self._conf.model . '.tokens_out', a:usage['completion_tokens'])

        let msg = self._usage['in'] . " in, " . self._usage['out'] . " out"

        call vimqq#log#info("mistral " . self.name() . " total usage: " . msg)

        call self.call_cb('status_cb', msg, self)
    endfunction

    function! l:mistral_bot._on_title_out(chat_id, msg) dict
        call add(self._title_reply_by_id[a:chat_id], a:msg)
    endfunction

    function l:mistral_bot._on_title_close(chat_id) dict
        let l:response = json_decode(join(self._title_reply_by_id[a:chat_id], '\n'))
        if has_key(l:response, 'choices') && !empty(l:response.choices) && has_key(l:response.choices[0], 'message')
            let l:title  = l:response.choices[0].message.content
            call self._update_usage(l:response.usage)
            call vimqq#model#notify('title_done', {'chat_id' : a:chat_id, 'title': title})
        else
            call vimqq#log#error('Unable to process response')
            call vimqq#log#error(json_encode(l:response))
            " TODO: still need to mark query as done
        endif
    endfunction

    function! l:mistral_bot._on_out(chat_id, msg) dict
        call add(self._reply_by_id[a:chat_id], a:msg)
    endfunction

    function! l:mistral_bot._on_err(chat_id, msg) dict
        call vimqq#log#error('mistral_bot error: ' . a:msg)
    endfunction

    function l:mistral_bot._on_close(chat_id) dict
        let l:response = join(self._reply_by_id[a:chat_id], '\n')
        call vimqq#log#debug('Mistral API reply: ' . l:response)
        let l:response = json_decode(l:response)
        if has_key(l:response, 'choices') && !empty(l:response.choices) && has_key(l:response.choices[0], 'message')
            let l:message  = l:response.choices[0].message.content
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

    function! l:mistral_bot._send_query(req, job_conf) dict
        let l:json_req  = json_encode(a:req)
        let l:json_req  = substitute(l:json_req, "'", "'\\\\''", "g")

        let l:curl_cmd  = "curl -s -X POST 'https://api.mistral.ai/v1/chat/completions'"
        let l:curl_cmd .= " -H 'Content-Type: application/json'"
        let l:curl_cmd .= " -H 'Accept: application/json'"
        let l:curl_cmd .= " -H 'Authorization: Bearer " . self._api_key . "'"
        let l:curl_cmd .= " -d '" . l:json_req . "'"

        return vimqq#jobs#start(['/bin/sh', '-c', l:curl_cmd], a:job_conf)
    endfunction

    function! l:mistral_bot._format_messages(messages) dict
        " Add system message
        let l:res = [{'role': 'system', 'content' : self._conf.system_prompt}]

        for msg in vimqq#fmt#many(a:messages)
            " Skipping empty messages
            if !empty(msg.content)
                call add (l:res, {'role': msg.role, 'content': msg.content})
            endif
        endfor
        return l:res
    endfunction

    " }}}

    function! l:mistral_bot.name() dict
        return self._conf.bot_name
    endfunction

    function! l:mistral_bot.do_autowarm() dict
        return self._conf.do_autowarm
    endfunction

    function! l:mistral_bot.send_warmup(messages) dict
      " do nothing for now
    endfunction

    function! l:mistral_bot.send_chat(chat_id, messages) dict
        let req = {}
        let req.model      = self._conf.model
        let req.messages   = self._format_messages(a:messages)
        let req.max_tokens = self._conf.max_tokens
        let self._reply_by_id[a:chat_id] = []

        let l:job_conf = {
              \ 'out_cb'  : {channel, msg -> self._on_out(a:chat_id, msg)}, 
              \ 'err_cb'  : {channel, msg -> self._on_err(a:chat_id, msg)},
              \ 'close_cb': {channel      -> self._on_close(a:chat_id)}
        \ }

        return self._send_query(req, l:job_conf)
    endfunction

    " ask for a title we'll use. Uses first message in a chat
    function! l:mistral_bot.send_gen_title(chat_id, message) dict
        let req = {}
        let l:message_text = vimqq#fmt#content(a:message)
        " TODO: make configurable and remove duplicate code with llama.vim
        let prompt = "Write a title with a few words summarizing the following paragraph. Reply only with title itself. Use no quotes around it.\n\n"
        let req.messages = [
            \ {'role': 'system', 'content' : self._conf.system_prompt},
            \ {"role": "user", "content": prompt . l:message_text}
        \]
        let req.max_tokens = self._conf.title_tokens
        let req.model      = self._conf.model

        let self._title_reply_by_id[a:chat_id] = []

        let l:job_conf = {
              \ 'out_cb'  : {channel, msg -> self._on_title_out(a:chat_id, msg)},
              \ 'close_cb': {channel      -> self._on_title_close(a:chat_id)}
        \ }

        return self._send_query(req, l:job_conf)
    endfunction

    return l:mistral_bot

endfunction
