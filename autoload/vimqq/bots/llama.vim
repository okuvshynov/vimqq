" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_llama_module')
    finish
endif

let g:autoloaded_vimqq_llama_module = 1

let s:healthcheck_ms = 10000

let s:default_conf = {
    \ 'title_tokens'  : 32,
    \ 'max_tokens'    : 1024,
    \ 'bot_name'      : 'llama',
    \ 'system_prompt' : 'You are a helpful assistant.',
    \ 'send_warmup'   : v:true,
    \ 'do_autowarm'   : v:true
\ }

function vimqq#bots#llama#new(config = {}) abort
    let l:config = deepcopy(s:default_conf)
    call extend(l:config, a:config)
    let l:server = substitute(l:config.addr, '/*$', '', '')
    let l:endpoint = l:server . '/v1/chat/completions'

    let l:impl = vimqq#api#llama_api#new(l:endpoint)

    return vimqq#client#new(l:impl, l:config)
endfunction
