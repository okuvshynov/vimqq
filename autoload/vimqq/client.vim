if exists('g:autoloaded_vimqq_client_module')
    finish
endif
let g:autoloaded_vimqq_client_module = 1

let s:default_conf = {
    \ 'title_tokens'  : 32,
    \ 'max_tokens'    : 1024,
    \ 'bot_name'      : 'ai',
    \ 'system_prompt' : 'You are a helpful assistant.',
    \ 'send_warmup'   : v:false,
    \ 'do_autowarm'   : v:false,
    \ 'model'         : ''
\ }

function! vimqq#client#new(impl, config = {}) abort
    let client = {}

    let client._conf = deepcopy(s:default_conf)
    call extend(client._conf, a:config)
    
    let client._impl = a:impl

    function! client.name() dict
        return self._conf.bot_name
    endfunction
    
    function! client.do_autowarm() dict
        return self._conf.do_autowarm
    endfunction

    function! client._on_warmup_complete(error, params) dict
        if a:error isnot v:null
            call vimqq#log#error('warmup call failed')
        endif
        call vimqq#events#notify('warmup_done', {'bot' : self})
    endfunction

    function! client.send_warmup(messages) dict
        if self._conf.send_warmup
            let req = {
            \   'messages' : self._format(a:messages),
            \   'max_tokens' : 0,
            \   'model' : self._conf.model,
            \   'on_complete' : {err, p -> self._on_warmup_complete(err, p)}
            \ }
            return self._impl.chat(req)
        endif
    endfunction

    function! client.send_gen_title(chat_id, message) dict
        let prompt = vimqq#prompts#gen_title_prompt(a:message)
        let messages = [
        \   {'role': 'system', 'content' : self._conf.system_prompt},
        \   {'role': 'user', 'content' : [{'type': 'text', 'text': prompt}]}
        \ ]

        " for non-streaming there'll be exactly one chunk
        let req = {
        \   'messages' : messages,
        \   'max_tokens' : self._conf.title_tokens,
        \   'model' : self._conf.model,
        \   'on_chunk' : {p, m -> vimqq#events#notify('title_done', {'chat_id' : a:chat_id, 'title': m})},
        \   'on_complete': {err, p -> vimqq#log#debug('title complete')}
        \ }
        return self._impl.chat(req)
    endfunction

    function! client.send_chat(chat, stream=v:true) dict
        let chat_id = a:chat.id
        let messages = a:chat.messages
        " here we attemt to do streaming. If API implementation
        " doesn't support it, it would 'stream' everything in single chunk

        let req = {
        \   'messages' : self._format(messages),
        \   'max_tokens' : self._conf.max_tokens,
        \   'model' : self._conf.model,
        \   'stream' : a:stream,
        \   'on_chunk' : {p, m -> vimqq#events#notify('chunk_done', {'chat_id': chat_id, 'chunk': m})},
        \   'on_complete' : {err, p -> vimqq#events#notify('reply_done', {'chat_id': chat_id, 'bot' : self})}
        \ }

        if has_key(a:chat, 'tools_allowed')
            let req['tools'] = a:chat.toolset
            let req['on_tool_use'] = {tool_call -> vimqq#events#notify('tool_use_recv', {'chat_id': chat_id, 'tool_use': tool_call})}
        endif

        return self._impl.chat(req)
    endfunction

    function! client._format(messages) dict
        let res = [{"role": "system", "content" : self._conf.system_prompt}]
        for msg in vimqq#fmt#many(a:messages)
            " Skipping empty messages
            if !empty(msg.content)
                call add (res, {'role': msg.role, 'content': msg.content})
            endif
        endfor
        return res
    endfunction

    return client
endfunction
