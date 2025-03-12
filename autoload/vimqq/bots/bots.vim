if exists('g:autoloaded_vimqq_bots')
    finish
endif
let g:autoloaded_vimqq_bots = 1

" configuration
let g:vqq_llama_cpp_servers = get(g:, 'vqq_llama_cpp_servers', [])
let g:vqq_llama_cpp_reviewer_models = get(g:, 'vqq_llama_cpp_reviewer_models', [])

let g:vqq_claude_models = get(g:, 'vqq_claude_models', [])
let g:vqq_claude_reviewer_models = get(g:, 'vqq_claude_reviewer_models', [])

let g:vqq_default_bot   = get(g:, 'vqq_default_bot',   '')

let s:MOCK_BOT_NAME = 'mqq'

" Validate a bot name to ensure it's unique and follows naming conventions
function! s:validate_name(name, bots)
    if a:name ==# s:MOCK_BOT_NAME
        call vimqq#log#error("Bot name '" . s:MOCK_BOT_NAME . "' is reserved for internal mock bot.")
        return v:false
    endif
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
function! s:create(config_lists)
    let res = []
    for [config_list, BotFactory] in a:config_lists
        for config in config_list
            if !has_key(config, 'bot_name')
                call vimqq#log#error("Each bot must have a 'bot_name' field")
                continue
            endif
            if s:validate_name(config.bot_name, res)
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
          \ [g:vqq_llama_cpp_servers, {conf -> vimqq#bots#llama_cpp#new(conf)}],
          \ [g:vqq_llama_cpp_reviewer_models, {conf -> vimqq#bots#llama_cpp_reviewer#new(conf)}],
          \ [g:vqq_claude_reviewer_models, {conf -> vimqq#bots#claude_reviewer#new(conf)}],
          \ [g:vqq_claude_models, {conf -> vimqq#bots#claude#new(conf)}]
    \]

    let bots._bots = s:create(config_lists)
    if empty(bots._bots)
        let err = 'No bots defined.'
        echoe err
        call vimqq#log#error(err)
        return
    endif
    let bots._default_bot = bots._bots[0]
    for bot in bots._bots
        if bot.name() ==# g:vqq_default_bot
            let bots._default_bot = bot
        endif
    endfor

    " add default mock bot
    let mock_bot = vimqq#bots#mock_bot#new({'bot_name': s:MOCK_BOT_NAME})
    call add(bots._bots, mock_bot)

    function! bots.bots() dict
        return self._bots
    endfunction

    function! bots.find(name) dict
        for bot in self._bots
            if bot.name() ==# a:name
                return bot
            endif
        endfor
        return v:null
    endfunction

    " Selects bot to ask based on question and last bot used in converation
    "   - if there's a tag, use that
    "   - if there's no tag, and current_bot is not null, use it
    "   - otherwise, use default bot
    function! bots.select(question, current_bot_name=v:null) dict
        let old_bot = v:null
        for bot in self._bots
            if bot.name() ==# a:current_bot_name
                let old_bot = bot
            endif
            let bot_tag = '@' . bot.name()
            if len(a:question) > len(bot_tag)
                let bot_tag .= ' '
            endif
            if strpart(a:question, 0, len(bot_tag)) ==# bot_tag
                " removing tag before passing it to backend
                let i = len(bot_tag)
                return [bot, strpart(a:question, i)]
            endif
        endfor
        if old_bot isnot v:null
            return [old_bot, a:question]
        endif
        return [self._default_bot, a:question]
    endfunction

    return bots
endfunction
