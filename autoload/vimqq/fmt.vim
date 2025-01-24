if exists('g:autoloaded_vimqq_fmt')
    finish
endif

let g:autoloaded_vimqq_fmt = 1

" receives message object. Picks the format based on selection/context
" We try to keep the message itself in the very end to allow for more
" effective warmup. 
"
" returns formatted content
function! vimqq#fmt#content(message, prompt)
    let replacements = {
        \ "{vqq_message}": {msg -> has_key(msg.sources, 'text') ? msg.sources.text : ''},
        \ "{vqq_context}": {msg -> has_key(msg.sources, 'context') ? msg.sources.context : ''},
        \ "{vqq_lucas_index}": {msg -> has_key(msg.sources, 'index') ? msg.sources.index : ''},
        \ "{vqq_lucas_index_size}": {msg -> has_key(msg.sources, 'index') ? len(msg.sources.index) : 0},
        \ "{vqq_tool_call}" : {msg -> has_key(msg, 'tool_use') ? "\n\n[tool_call: " . msg.tool_use.name . "(...)]": ""}
        \ }

    let res = a:prompt
    for [pattern, ContextFn] in items(replacements)
        let escaped = escape(ContextFn(a:message), (&magic ? '&~' : ''))
        let res = substitute(res, pattern, escaped, 'g')
    endfor

    return res
endfunction

function! s:format_message(message) abort
    let prompt = vimqq#prompts#pick(a:message, v:false)
    return vimqq#fmt#content(a:message, prompt)
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
