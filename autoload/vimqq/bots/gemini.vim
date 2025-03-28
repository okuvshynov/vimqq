if exists('g:autoloaded_vimqq_gemini_module')
    finish
endif

let g:autoloaded_vimqq_gemini_module = 1

function! vimqq#bots#gemini#new(config = {}) abort
    let DEFAULT_CONF = {
        \ 'bot_name'       : 'gemini',
        \ 'title_tokens'   : 64,
        \ 'max_tokens'     : 2000,
        \ 'system_prompt'  : 'You are an AI assistant named Gemini. Help the user with their questions or tasks.',
        \ 'warmup'         : v:true,
        \ 'use_jinja'      : v:false,
    \ }
    
    " Merge provided config with defaults
    let conf = extend(copy(DEFAULT_CONF), a:config)
    
    " Extract model name from configuration
    let model_name = get(conf, 'model', 'gemini-pro')
    
    " Create the Gemini API instance
    let api = vimqq#api#gemini_api#new()
    
    " Create a new bot instance using the base bot class
    return vimqq#bots#bot#new({
        \ 'api'            : api,
        \ 'bot_name'       : conf.bot_name,
        \ 'model'          : model_name,
        \ 'title_tokens'   : conf.title_tokens,
        \ 'max_tokens'     : conf.max_tokens,
        \ 'system_prompt'  : conf.system_prompt,
        \ 'warmup'         : conf.warmup,
        \ 'use_jinja'      : conf.use_jinja,
    \ })
endfunction