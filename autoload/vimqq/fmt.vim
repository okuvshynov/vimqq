if exists('g:autoloaded_vimqq_fmt')
    finish
endif

let g:autoloaded_vimqq_fmt = 1

function! s:format_message(message) abort
    let prompt = vimqq#prompts#pick(a:message, v:false)
    return vimqq#prompts#apply(a:message, prompt)
endfunction

function! vimqq#fmt#for_wire(message) abort
    let new_msg = deepcopy(a:message)

    " check if this is tool response
    if has_key(a:message, 'content')
        if a:message.content[0].type ==# 'tool_result'
            return new_msg
        endif
    endif

    if has_key(a:message, 'tool_use')
        let tool_use = {
            \ 'type': 'tool_use',
            \ 'id': a:message.tool_use.id,
            \ 'name': a:message.tool_use.name,
            \ 'input': a:message.tool_use.input
        \ }
        let new_msg.content = [{'type': 'text', 'text': s:format_message(a:message)}, tool_use]
        return new_msg
    endif

    let new_msg.content = [{'type': 'text', 'text': s:format_message(a:message)}]
    return new_msg
endfunction

function! vimqq#fmt#many(messages)
    let new_messages = []
    for msg in a:messages
        call add(new_messages, vimqq#fmt#for_wire(msg))
    endfor
    return new_messages
endfunction
