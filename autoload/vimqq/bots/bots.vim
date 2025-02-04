if exists('g:autoloaded_vimqq_bots')
    finish
endif
let g:autoloaded_vimqq_bots = 1

" configuration
let g:vqq_llama_servers = get(g:, 'vqq_llama_servers', [])
let g:vqq_claude_models = get(g:, 'vqq_claude_models', [])
let g:vqq_deepseek_models = get(g:, 'vqq_deepseek_models', [])
let g:vqq_reviewer_models = get(g:, 'vqq_reviewer_models', [])
let g:vqq_local_reviewer_models = get(g:, 'vqq_local_reviewer_models', [])
let g:vqq_claude_reviewer_models = get(g:, 'vqq_claude_reviewer_models', [])
let g:vqq_default_bot   = get(g:, 'vqq_default_bot',   '')

" Validate a bot name to ensure it's unique and follows naming conventions
function! s:_validate_name(name, bots)
    if a:name ==# 'You'
        call vimqq#log#error("Bot name 'You' is not allowed")
        return v:false
    endif

    " Check if name contains only allowed characters
    if a:name !~# '^[A-Za-z0-9_]\+$'
        call vimqq#log#error("Bot name must contain only letters, numbers, and underscores")
        return v:false
    endif

    " Check if a bot with the same name already exists
    for client in a:bots
        if client.name() ==# a:name
            call vimqq#log#error("A bot with the name '" . a:name . "' already exists")
            return v:false
        endif
    endfor
    return v:true
endfunction

" Create a list of bot instances from configuration lists
function! s:_create(config_lists)
    let res = []
    for [config_list, BotFactory] in a:config_lists
        for config in config_list
            if !has_key(config, 'bot_name')
                call vimqq#log#error("Each bot must have a 'bot_name' field")
                continue
            endif
            if s:_validate_name(config.bot_name, res)
                call add(res, BotFactory(config))
            endif
        endfor
    endfor
    return res
endfunction

" Create a new bot manager instance
function! vimqq#bots#bots#new() abort
    let bots = {}

    let config_lists = [
          \ [g:vqq_llama_servers, {conf -> vimqq#bots#llama#new(conf)}],
          \ [g:vqq_deepseek_models, {conf -> vimqq#bots#deepseek#new(conf)}],
          \ [g:vqq_reviewer_models, {conf -> vimqq#bots#deepseek_reviewer#new(conf)}],
          \ [g:vqq_local_reviewer_models, {conf -> vimqq#bots#local_reviewer#new(conf)}],
          \ [g:vqq_claude_reviewer_models, {conf -> vimqq#bots#claude_reviewer#new(conf)}],
          \ [g:vqq_claude_models, {conf -> vimqq#bots#claude#new(conf)}]
    \]

    let bots._bots = s:_create(config_lists)
    if empty(bots._bots)
        call vimqq#log#error('No bots defined. See :h vimqq-install').
        finish
    endif
    let bots._default_bot = bots._bots[0]
    for bot in bots._bots
        if bot.name() ==# g:vqq_default_bot
            let bots._default_bot = bot
        endif
    endfor

    function! bots.bots() dict
        return self._bots
    endfunction

    function! bots.select(question) dict
        for bot in self._bots
            let bot_tag = '@' . bot.name()
            if len(a:question) > len(bot_tag)
                let bot_tag .= ' '
            endif
            "call vimqq#log#debug(bot_tag . "|")
            if strpart(a:question, 0, len(bot_tag)) ==# bot_tag
                " removing tag before passing it to backend
                let i = len(bot_tag)
                return [bot, strpart(a:question, i)]
            endif
        endfor
        return [self._default_bot, a:question]
    endfunction

    return bots
endfunction
