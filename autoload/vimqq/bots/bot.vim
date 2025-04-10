if exists('g:autoloaded_vimqq_bot_module')
    finish
endif
let g:autoloaded_vimqq_bot_module = 1

let s:DEFAULT_CONF = {
    \ 'title_tokens'  : 32,
    \ 'max_tokens'    : 1024,
    \ 'thinking_tokens' : 0,
    \ 'bot_name'      : 'ai',
    \ 'system_prompt' : 'You are a helpful assistant.',
    \ 'warmup_on_typing'   : v:false,
    \ 'warmup_on_select'   : v:false,
    \ 'model'         : ''
\ }

function! vimqq#bots#bot#new(impl, config = {}) abort
    let bot = {}

    let bot._conf = deepcopy(s:DEFAULT_CONF)
    call extend(bot._conf, a:config)
    
    let bot._impl    = a:impl

    function! bot.name() dict
        return self._conf.bot_name
    endfunction
    
    function! bot.warmup_on_select() dict
        return self._conf.warmup_on_select
    endfunction

    function! bot.warmup_on_typing() dict
        return self._conf.warmup_on_typing
    endfunction

    function! bot._on_warmup_complete(error, params) dict
        if a:error isnot v:null
            call vimqq#log#error('warmup call failed')
        endif
        call vimqq#main#notify('warmup_done', {'bot' : self})
    endfunction

    function! bot.send_warmup(messages) dict
        let req = {
        \   'messages' : self._format(a:messages),
        \   'max_tokens' : 0,
        \   'model' : self._conf.model,
        \   'on_complete' : {err, p, m -> self._on_warmup_complete(err, p)}
        \ }
        return self._impl.chat(req)
    endfunction

    function! bot.on_usage(chat_id, usage) dict
        call vimqq#main#on_usage(a:chat_id, self.name(), a:usage)
    endfunction

    " This will set the bots instance so we can get other bot
    " by name in case we need it for override (e.g. title gen)
    function! bot.set_factory(factory) dict
        let self.factory = a:factory
    endfunction

    " If 'title_bot_override' exists
    " And bot with that name exists
    " Use that bot for title gen
    " This is important as we might not want mess up the KV cache
    " for main bot and can use much cheaper model for title gen
    function! bot.title_override_bot() dict
        if !has_key(self, 'factory')
            call vimqq#log#debug('no bot factory instance.')
            return v:null
        endif
        let title_override_name = get(self._conf, 'title_gen_bot', '')
        return self.factory.find(title_override_name)
    endfunction

    function! bot.send_gen_title(chat_id, message) dict
        let title_bot = self.title_override_bot()
        if title_bot isnot v:null
            return title_bot.send_gen_title(a:chat_id, a:message)
        endif

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
        \   'on_chunk' : {p, m -> vimqq#main#notify('title_done', {'chat_id' : a:chat_id, 'title': m, 'bot': self})},
        \   'on_complete': {err, p, m -> vimqq#log#debug('title complete')},
        \   'on_usage': {u -> self.on_usage(a:chat_id, u)},
        \   'on_sys_msg' : {lvl, msg -> vimqq#sys_msg#log(lvl, chat_id, msg)}
        \ }
        return self._impl.chat(req)
    endfunction

    function! bot.send_chat(chat, stream=v:true) dict
        let chat_id = a:chat.id

        " This is request we send to API layer. APIs implementation (e.g.
        " anthropic, llama.cpp, deepseek, together.ai, etc) will reformat
        " our internal message formatting according to API rules.
        " The result will be provided through callbacks.
        let req = {
        \   'messages' : self._format(a:chat.messages),
        \   'max_tokens' : self._conf.max_tokens,
        \   'model' : self._conf.model,
        \   'stream' : a:stream,
        \   'on_chunk' : {p, m -> vimqq#main#on_chunk_done({'chat_id': chat_id, 'chunk': m, 'builder': p._builder, 'bot': self})},
        \   'on_complete' : {err, p, m -> vimqq#main#notify('reply_done', {'chat_id': chat_id, 'bot' : self, 'msg' : m})},
        \   'on_usage': {u -> self.on_usage(chat_id, u)},
        \   'on_sys_msg' : {lvl, msg -> vimqq#sys_msg#log(lvl, chat_id, msg)}
        \ }

        if has_key(a:chat, 'tools_allowed')
            let req['tools'] = a:chat.toolset
        endif

        if get(self._conf, 'thinking_tokens', 0) > 0
            let req['thinking_tokens'] = self._conf['thinking_tokens']
        endif

        return self._impl.chat(req)
    endfunction

    function! bot._format(messages) dict
        " TODO: shall we save this to the chat itself?
        let res = [{"role": "system", "content" : self._conf.system_prompt}]
        for msg in a:messages
            if msg['role'] ==# 'local'
                continue
            endif
            call add (res, {'role': msg.role, 'content': msg.content})
        endfor
        return res
    endfunction

    return bot
endfunction
