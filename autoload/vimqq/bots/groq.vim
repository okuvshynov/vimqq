" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_groq_module')
    finish
endif

let g:autoloaded_vimqq_groq_module = 1

" API key for groq
let g:vqq_groq_api_key = get(g:, 'vqq_groq_api_key', $GROQ_API_KEY)

function! vimqq#bots#groq#new(config = {}) abort
    " Start with base bot
    let l:groq_bot = vimqq#bots#bot#new(extend(
        \ {'bot_name': 'groq'}, 
        \ a:config))
    
    let l:groq_bot._api_key = g:vqq_groq_api_key

    " {{{ private:
    
    function! l:groq_bot.get_usage(response) dict
        let usage = {}
        let usage['in'] = get(a:response.usage, 'prompt_tokens', 0)
        let usage['out'] = get(a:response.usage, 'completion_tokens', 0)
        return usage
    endfunction

    function! l:groq_bot._on_out(chat_id, msg) dict
        call add(self._reply_by_id[a:chat_id], a:msg)
    endfunction

    function! l:groq_bot._on_err(chat_id, msg) dict
        call vimqq#log#error('groq_bot error: ' . a:msg)
    endfunction

    function l:groq_bot._on_close(chat_id) dict
        let l:response = join(self._reply_by_id[a:chat_id], '\n')
        call vimqq#log#debug('Groq reply: ' . l:response)
        let l:response = json_decode(l:response)
        if has_key(l:response, 'choices') && !empty(l:response.choices) && has_key(l:response.choices[0], 'message')
            let l:message  = l:response.choices[0].message.content
            call self._update_usage(l:response)
            " we pretend it's one huge update
            call vimqq#model#notify('token_done', {'chat_id': a:chat_id, 'token': l:message})
            " and immediately done
            call vimqq#model#notify('reply_done', {'chat_id': a:chat_id, 'bot': self})
        else
            call vimqq#log#error('Unable to process response')
            call vimqq#log#error(json_encode(l:response))
            " TODO: still need to mark query as done. 
        endif
    endfunction

    function! l:groq_bot._send_query(req, job_conf) dict
        let l:json_req = json_encode(a:req)
        let l:headers = {
            \ 'Content-Type': 'application/json',
            \ 'Authorization': 'Bearer ' . self._api_key
        \ }
        return vimqq#platform#http_client#post(
            \ 'https://api.groq.com/openai/v1/chat/completions',
            \ l:headers,
            \ l:json_req,
            \ a:job_conf)
    endfunction

    function! l:groq_bot._format_messages(messages) dict
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

    function! l:groq_bot.send_warmup(messages) dict
      " do nothing for now
    endfunction

    function! l:groq_bot.send_chat(chat_id, messages) dict
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

    " public methods required by base bot for title generation
    function! l:groq_bot.get_req(user_content) dict
        let req = {}
        let req.messages = [
            \ {'role': 'system', 'content' : self._conf.system_prompt},
            \ {"role": "user", "content": a:user_content}
        \]
        let req.max_tokens = self._conf.title_tokens
        let req.model      = self._conf.model
        return req
    endfunction

    function! l:groq_bot.get_response_text(response) dict
        return a:response.choices[0].message.content
    endfunction

    return l:groq_bot

endfunction
