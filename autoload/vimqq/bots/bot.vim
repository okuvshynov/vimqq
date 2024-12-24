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

    return l:bot
endfunction
