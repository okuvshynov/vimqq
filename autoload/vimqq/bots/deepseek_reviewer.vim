" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_deepseek_reviewer_module')
    finish
endif

let g:autoloaded_vimqq_deepseek_reviewer_module = 1

function! vimqq#bots#deepseek_reviewer#new(config = {}) abort
    let impl = vimqq#api#deepseek_api#new()
    let base_client = vimqq#client#new(impl, a:config)

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
