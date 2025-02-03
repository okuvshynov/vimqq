" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_local_reviewer_module')
    finish
endif

let g:autoloaded_vimqq_local_reviewer_module = 1

let s:default_conf = {
    \ 'title_tokens'  : 32,
    \ 'max_tokens'    : 1024,
    \ 'bot_name'      : 'llama',
    \ 'system_prompt' : 'You are a helpful assistant.',
    \ 'send_warmup'   : v:true,
    \ 'do_autowarm'   : v:true
\ }

function vimqq#bots#local_reviewer#new(config = {}) abort
    let config = deepcopy(s:default_conf)
    call extend(config, a:config)
    let server = substitute(config.addr, '/*$', '', '')
    let endpoint = server . '/v1/chat/completions'

    let impl = vimqq#api#llama_api#new(endpoint)

    let base_client = vimqq#bots#bot#new(impl, config)

    function! base_client._format(messages) dict
        let res = [{"role": "system", "content" : vimqq#prompts#reviewer_prompt()}]
        let lines = []
        for message in a:messages
            call extend(lines, vimqq#fmt_ui#ui(message))
        endfor

        let content = join(lines, "\n")

        call vimqq#log#debug('REVIEW CONTENT: ' . content)

        call add(res, {'role': 'user', 'content': content})

        return res
    endfunction

    return base_client
endfunction
