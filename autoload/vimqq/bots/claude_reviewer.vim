" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_claude_reviewer_module')
    finish
endif

let g:autoloaded_vimqq_claude_reviewer_module = 1

function! vimqq#bots#claude_reviewer#new(config = {}) abort
    let impl = vimqq#api#anthropic_api#new({})
    let bot = vimqq#bots#bot#new(impl, a:config)

    function! bot._format(messages) dict
        let res = [{"role": "system", "content" : vimqq#prompts#reviewer_prompt()}]
        let lines = []
        for message in a:messages
            call extend(lines, vimqq#fmt_ui#ui(message))
        endfor

        let content = [{'type': 'text', 'text': join(lines, "\n")}]

        "call vimqq#log#debug('REVIEW CONTENT: ' . content)

        call add(res, {'role': 'user', 'content': content})

        return res
    endfunction

    return bot
endfunction
