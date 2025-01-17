" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_llama_module')
    finish
endif

let g:autoloaded_vimqq_llama_module = 1

let s:default_conf = {
    \ 'title_tokens'  : 32,
    \ 'max_tokens'    : 1024,
    \ 'bot_name'      : 'llama',
    \ 'system_prompt' : 'You are a helpful assistant.',
    \ 'send_warmup'   : v:true,
    \ 'do_autowarm'   : v:true
\ }

function vimqq#bots#llama#new(config = {}) abort
    let config = deepcopy(s:default_conf)
    call extend(config, a:config)
    let server = substitute(config.addr, '/*$', '', '')
    let endpoint = server . '/v1/chat/completions'

    let impl = vimqq#api#llama_api#new(endpoint)

    return vimqq#client#new(impl, config)
endfunction
