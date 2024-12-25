" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_bot_module')
    finish
endif
let g:autoloaded_vimqq_bot_module = 1

let s:default_conf = {
  \ 'title_tokens'   : 16,
  \ 'max_tokens'     : 1024,
  \ 'bot_name'       : 'base',
  \ 'system_prompt'  : 'You are a helpful assistant.',
  \ 'do_autowarm'    : v:false
\ }

function! vimqq#bots#bot#new(config = {}) abort
    let l:bot = {}
    
    let l:bot._conf = deepcopy(s:default_conf)
    call extend(l:bot._conf, a:config)
    
    " Common usage tracking
    let l:bot._usage = {'in': 0, 'out': 0}
    
    " Storage for responses
    let l:bot._reply_by_id = {}
    let l:bot._title_reply_by_id = {}
    
    " {{{ public interface

    function! l:bot.name() dict
        return self._conf.bot_name
    endfunction
    
    function! l:bot.do_autowarm() dict
        return self._conf.do_autowarm
    endfunction

    " Default implementations
    function! l:bot.send_warmup(messages) dict
        " Do nothing by default, bot implementations can override
    endfunction

    function! l:bot._update_usage(response) dict
        let usage = self.get_usage(a:response)
        let self._usage['in']  += usage['in']
        let self._usage['out'] += usage['out']

        let key = self.name()
        call vimqq#metrics#inc(key . '.tokens_in', usage['in'])
        call vimqq#metrics#inc(key . '.tokens_out', usage['out'])

        let msg = self._usage['in'] . " in, " . self._usage['out'] . " out"

        call vimqq#log#info(key . " total usage: " . msg)

        call vimqq#model#notify('bot_status', {'status' : msg, 'bot': self})
    endfunction

    function! l:bot._on_title_out(chat_id, msg) dict
        call add(self._title_reply_by_id[a:chat_id], a:msg)
    endfunction

    function! l:bot._on_title_close(chat_id) dict
        let l:response = json_decode(join(self._title_reply_by_id[a:chat_id], '\n'))
        let l:title  = self.get_response_text(l:response)
        call self._update_usage(l:response)
        call vimqq#model#notify('title_done', {'chat_id' : a:chat_id, 'title': l:title})
    endfunction

    function! l:bot.send_gen_title(chat_id, message) dict
        let self._title_reply_by_id[a:chat_id] = []
        let l:message_text = vimqq#fmt#content(a:message)
        let prompt = vimqq#prompts#gen_title_prompt()

        let req = self.get_req(prompt . l:message_text)
        let l:job_conf = {
              \ 'out_cb'  : {channel, msg -> self._on_title_out(a:chat_id, msg)},
              \ 'close_cb': {channel      -> self._on_title_close(a:chat_id)}
        \ }

        return self._send_query(req, l:job_conf)
    endfunction

    function! l:bot._format_messages(messages) dict
        let l:res = []
        for msg in vimqq#fmt#many(a:messages)
            " Skipping empty messages
            if !empty(msg.content)
                call add (l:res, {'role': msg.role, 'content': msg.content})
            endif
        endfor
        return l:res
    endfunction

    return l:bot
endfunction
