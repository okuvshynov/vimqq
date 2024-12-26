" This is generic open-ai-like non-streaming bot
" It is abstract class, implementations (mistral, groq, etc) 
" need to implement _send_query

if exists('g:autoloaded_vimqq_bot_openai_module')
    finish
endif

let g:autoloaded_vimqq_bot_openai_module = 1

function! vimqq#bots#openai#new(config = {}) abort
    " Start with base bot
    let l:bot = vimqq#bots#bot#new(a:config)
    
    " {{{ private:
    function! l:bot.get_usage(response) dict
        let usage = {}
        let usage['in'] = get(a:response.usage, 'prompt_tokens', 0)
        let usage['out'] = get(a:response.usage, 'completion_tokens', 0)
        return usage
    endfunction

    function! l:bot._on_out(chat_id, msg) dict
        call add(self._reply_by_id[a:chat_id], a:msg)
    endfunction

    function! l:bot._on_err(chat_id, msg) dict
        call vimqq#log#error('bot error: ' . a:msg)
    endfunction

    function l:bot._on_close(chat_id) dict
        let l:response = join(self._reply_by_id[a:chat_id], '\n')
        let l:response = json_decode(l:response)
        if has_key(l:response, 'choices') && !empty(l:response.choices) && has_key(l:response.choices[0], 'message')
            let l:message  = l:response.choices[0].message.content
            call self._update_usage(l:response)
            " we pretend it's one huge update
            call vimqq#model#notify('chunk_done', {'chat_id': a:chat_id, 'chunk': l:message})
            " and immediately done
            call vimqq#model#notify('reply_done', {'chat_id': a:chat_id, 'bot': self})
        else
            call vimqq#log#error('Unable to process response')
            call vimqq#log#error(json_encode(l:response))
            " TODO: still need to mark query as done
        endif
    endfunction

    function! l:bot._prepare_request(messages) dict
        let l:sys = [{'role': 'system', 'content' : self._conf.system_prompt}]
        let req = {}
        let req.model      = self._conf.model
        let req.messages   = l:sys + self._format_messages(a:messages)
        let req.max_tokens = self._conf.max_tokens

        return req
    endfunction


    " }}}

    function! l:bot.send_warmup(messages) dict
      " do nothing for now
    endfunction

    function! l:bot.send_chat(chat_id, messages) dict
        let req = self._prepare_request(a:messages)
        let self._reply_by_id[a:chat_id] = []

        let l:job_conf = {
              \ 'out_cb'  : {channel, msg -> self._on_out(a:chat_id, msg)}, 
              \ 'err_cb'  : {channel, msg -> self._on_err(a:chat_id, msg)},
              \ 'close_cb': {channel      -> self._on_close(a:chat_id)}
        \ }

        return self._send_query(req, l:job_conf)
    endfunction

    " Following interface required by bot.vim for title generation
    function! l:bot.get_req(user_content) dict
        let req = {}
        let req.messages = [
            \ {'role': 'system', 'content' : self._conf.system_prompt},
            \ {"role": "user", "content": a:user_content}
        \]
        let req.max_tokens = self._conf.title_tokens
        let req.model      = self._conf.model
        return req
    endfunction

    function! l:bot.get_response_text(response) dict
        return a:response.choices[0].message.content
    endfunction

    return l:bot

endfunction
