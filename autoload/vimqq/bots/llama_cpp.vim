" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_llama_cpp_module')
    finish
endif

let g:autoloaded_vimqq_llama_cpp_module = 1

let s:default_conf = {
    \ 'bot_name'      : 'llama',
    \ 'system_prompt' : 'You are a helpful assistant.',
    \ 'send_warmup'   : v:true,
    \ 'do_autowarm'   : v:true,
    \ 'jinja'         : v:false
\ }

function vimqq#bots#llama_cpp#new(config = {}) abort
    let config = deepcopy(s:default_conf)
    call extend(config, a:config)
    let server = substitute(config.addr, '/*$', '', '')
    let config.endpoint = server . '/v1/chat/completions'

    let impl = vimqq#api#llama_api#new(config)

    return vimqq#bots#bot#new(impl, config)
endfunction
