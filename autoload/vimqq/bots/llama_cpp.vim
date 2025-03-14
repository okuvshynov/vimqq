" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_llama_cpp_bot_module')
    finish
endif

let g:autoloaded_vimqq_llama_cpp_bot_module = 1

let s:DEFAULT_CONF = {
    \ 'bot_name'      : 'llama',
    \ 'system_prompt' : 'You are a helpful assistant.',
    \ 'warmup_on_typing' : v:true,
    \ 'warmup_on_select' : v:true,
    \ 'jinja'         : v:false
\ }

function vimqq#bots#llama_cpp#new(config = {}) abort
    let config = deepcopy(s:DEFAULT_CONF)
    call extend(config, a:config)
    let config.endpoint = substitute(config.addr, '/*$', '', '')

    let impl = vimqq#api#llama_api#new(config)

    return vimqq#bots#bot#new(impl, config)
endfunction
