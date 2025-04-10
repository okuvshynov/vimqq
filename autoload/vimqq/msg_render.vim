if exists('g:autoloaded_vimqq_message_render')
    finish
endif

let g:autoloaded_vimqq_message_render = 1

" Rendered message has following fields:
" - timestamp
" - author: (user + tagged bot, bot, tool, local level - info, etc.
" - text

" tool output longer than 500 bytes will be hidden in fold
" we are not using line count to capture the case when it is one extremely
" long line, which will make chat hard to read.
let s:TOOL_FOLD_LIMIT = 500

function! s:render_local(msg) abort
    if exists('g:vqq_hide_local_msg')
        return v:null
    endif
    let text = ""
    for content in a:msg.content
        if content['type'] ==# 'text'
            let text = text . content['text']
        endif
    endfor
    return { 
        \ 'timestamp' : a:msg['timestamp'],
        \ 'author'    : get(a:msg, 'level', 'info') . ': ',
        \ 'text'      : text
    \ }
endfunction

function! s:render_tool_results(msg) abort
    let res = ""

    for content in a:msg.content
        if content.type ==# 'tool_result'
            let text = content['content']
            if len(text) >= s:TOOL_FOLD_LIMIT
                let text = "\n\n{{{ \n" . text . "\n}}}\n\n"
            else
                let text = "\n\n" . text . "\n\n"
            endif
            let res = res . text
        else
            call vimqq#log#warning('unexpected content type: ' . content.type)
        endif
    endfor

    return { 'text' : res }
endfunction

function! s:is_tool_result(msg) abort
    return ( a:msg.content[0]['type'] ==# 'tool_result' )
endfunction

" Currently there are two situations we need to handle:
" 1. It is one or more tool results
" 2. It is a single text (user input + context)
" These situations are mutually exclusive currently.
function! s:render_user(msg) abort
    if s:is_tool_result(a:msg)
        return s:render_tool_results(a:msg)
    endif

    " TODO: this needs to be done just once.
    " otherwise, if prompt changes, we will
    " show/send different message, and that will mess up
    " entire conversation
    "
    " Instead, we should just have 2 versions of text
    " stored inside the message - one for ui and one for wire.
    let prompt = vimqq#prompts#pick(a:msg, v:true)
    let text = vimqq#prompts#apply(a:msg, prompt)
    return {
        \ 'timestamp' : a:msg['timestamp'],
        \ 'author'    : 'You: @' . a:msg['bot_name'] . ' ',
        \ 'text'      : text
    \ }
endfunction

" assistant message can have multiple pieces of content 
" of different type
function! s:render_assistant(msg) abort
    let res = []
    for content in a:msg.content
        if content.type ==# 'text'
            call add(res, content.text)
        endif
        if content.type ==# 'tool_use'
            call add(res, vimqq#tools#toolset#format(content))
        endif
        if content.type ==# 'thinking'
            call add(res, "\n\n{{{ [thinking]\n" . content.thinking . "\n}}}\n\n")
        endif
        if content.type ==# 'redacted_thinking'
            call add(res, "\n\n[hidden thinking]\n")
        endif
    endfor
    return {
        \ 'timestamp' : a:msg['timestamp'],
        \ 'author'    : a:msg['bot_name'] . ': ',
        \ 'text'      : join(res, "\n")
    \ }
endfunction

function! vimqq#msg_render#render(msg)
    if a:msg.role ==# 'local'
        return s:render_local(a:msg)
    endif
    if a:msg.role ==# 'user'
        return s:render_user(a:msg)
    endif
    if a:msg.role ==# 'assistant'
        return s:render_assistant(a:msg)
    endif
    call vimqq#log#error('role not valid: ' . a:msg.role)
    return v:null
endfunction

" returns a list of lines, not rendered message
function! vimqq#msg_render#render_lines(message)
    let TIME_FORMAT = "%H:%M"
    let rendered = vimqq#msg_render#render(a:message)

    if rendered is v:null
        call vimqq#log#info('skip rendering message')
        return []
    endif

    let prompt = ""
    if has_key(rendered, 'timestamp')
        let prompt = strftime(TIME_FORMAT . " ", rendered['timestamp'])
    endif
    let prompt = prompt . get(rendered, 'author', '')
    return split(prompt . get(rendered, 'text', ''), '\n')
endfunction
