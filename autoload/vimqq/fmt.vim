if exists('g:autoloaded_vimqq_fmt')
    finish
endif

let g:autoloaded_vimqq_fmt = 1

function! s:load_index_lines()
    let l:current_dir = expand('%:p:h')
    let l:prev_dir = ''

    while l:current_dir !=# l:prev_dir
      " Check if lucas.idx file exists in current dir
      let l:file_path = l:current_dir . '/lucas.idx'
      if filereadable(l:file_path)
          return readfile(l:file_path)
      endif

      let l:prev_dir = l:current_dir
      let l:current_dir = fnamemodify(l:current_dir, ':h')
    endwhile
    return v:null
endfunction

" Fill context into message object
function! vimqq#fmt#fill_context(message, context, use_index)
    let l:message = deepcopy(a:message)

    if a:context isnot v:null
        let l:message.sources.context = a:context
    endif
    if a:use_index
        " TODO: Do we save index snapshot here?
        let l:index_lines = s:load_index_lines()
        if l:index_lines isnot v:null
            let l:message.sources.index = join(l:index_lines, '\n')
        else
            call vimqq#log#error('Unable to locate lucas.idx file')
        endif
    endif
    return l:message
endfunction

" receives message object. Picks the format based on selection/context
" We try to keep the message itself in the very end to allow for more
" effective warmup. 
"
" returns formatted content
function! vimqq#fmt#content(message, for_ui=v:false)
    let l:res = vimqq#prompts#pick(a:message, a:for_ui)
    let l:replacements = {
        \ "{vqq_message}": {msg -> has_key(msg.sources, 'text') ? msg.sources.text : ''},
        \ "{vqq_context}": {msg -> has_key(msg.sources, 'context') ? msg.sources.context : ''},
        \ "{vqq_lucas_index}": {msg -> has_key(msg.sources, 'index') ? msg.sources.index : ''},
        \ "{vqq_lucas_index_size}": {msg -> has_key(msg.sources, 'index') ? len(msg.sources.index) : 0},
        \ "{vqq_tool_call}" : {msg -> has_key(msg, 'tool_use') ? "\n\n[tool_call: " . msg.tool_use.name . "(...)]": ""}
        \ }

    for [pattern, ContextFn] in items(l:replacements)
        let l:escaped = escape(ContextFn(a:message), (&magic ? '&~' : ''))
        let l:res = substitute(l:res, pattern, l:escaped, 'g')
    endfor

    return l:res
endfunction

function! vimqq#fmt#one(message, for_ui=v:false)
    let new_msg = deepcopy(a:message)

    if a:for_ui
        if new_msg['role'] ==# 'user'
            let new_msg['author'] = 'You: @' . a:message['bot_name'] . " "
        else
            let new_msg['author'] = new_msg['bot_name'] . ": "
        endif
    endif

    " check if this is tool response
    if has_key(a:message, 'content')
        if a:message.content[0].type ==# 'tool_result'
            " if for UI:
            if a:for_ui
                let new_msg.content = [{'type': 'text', 'text': "\n\n[tool_call_result]"}]
                let new_msg.author = 'tool: @' . a:message['bot_name'] . " " 
                return new_msg
            else
                return new_msg
            endif
        endif
    endif

    if has_key(a:message, 'tool_use')
        let tool_use = {
            \ 'type': 'tool_use',
            \ 'id': a:message.tool_use.id,
            \ 'name': a:message.tool_use.name,
            \ 'input': a:message.tool_use.input
        \}
        let new_msg.content = [{'type': 'text', 'text': vimqq#fmt#content(a:message, a:for_ui)}, tool_use]
        return new_msg
    endif

    let new_msg.content = [{'type': 'text', 'text': vimqq#fmt#content(a:message, a:for_ui)}]
    return new_msg
endfunction

function! vimqq#fmt#many(messages, for_ui=v:false)
    let new_messages = []
    for msg in a:messages
        call add(new_messages, vimqq#fmt#one(msg, a:for_ui))
    endfor
    return new_messages
endfunction
