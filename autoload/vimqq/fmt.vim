if exists('g:autoloaded_vimqq_fmt')
    finish
endif

let g:autoloaded_vimqq_fmt = 1

function! s:message_text(message) abort
    let prompt = vimqq#prompts#pick(a:message, v:false)
    return vimqq#prompts#apply(a:message, prompt)
endfunction

" public only for tests
function! vimqq#fmt#for_wire(message) abort
    let new_msg = deepcopy(a:message)

    " check if this is tool response
    if has_key(a:message, 'content')
        if a:message.content[0].type ==# 'tool_result'
            return new_msg
        endif
    endif

    let text = s:message_text(a:message)
    if has_key(a:message, 'tool_use')
        let tool_use = {
            \ 'type': 'tool_use',
            \ 'id': a:message.tool_use.id,
            \ 'name': a:message.tool_use.name,
            \ 'input': a:message.tool_use.input
        \ }
        if empty(text)
            let new_msg.content = [tool_use]
        else
            let new_msg.content = [{'type': 'text', 'text': text}, tool_use]
        endif
        return new_msg
    endif

    let new_msg.content = [{'type': 'text', 'text': text}]
    return new_msg
endfunction

function! vimqq#fmt#many(messages)
    let new_messages = []
    for msg in a:messages
        if has_key(msg, 'role')
            if msg.role ==# 'local'
                continue
            endif
        endif
        call add(new_messages, vimqq#fmt#for_wire(msg))
    endfor
    return new_messages
endfunction
