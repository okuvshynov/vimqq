" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_claude_reviewer_module')
    finish
endif

let g:autoloaded_vimqq_claude_reviwer = 1

function! vimqq#bots#claude_reviewer#new(config = {}) abort
    let impl = vimqq#api#anthropic_api#new()
    let client = vimqq#client#new(impl, a:config)

    function! client._format(messages) dict
        let res = [{"role": "system", "content" : vimqq#prompts#reviewer_prompt()}]
        for msg in vimqq#fmt#many(a:messages)
            " Skipping empty messages
            " TODO: this should never happen
            if !empty(msg.content)
                call add (res, {'role': msg.role, 'content': msg.content})
            endif
        endfor
        return res
    endfunction

    return client
endfunction
