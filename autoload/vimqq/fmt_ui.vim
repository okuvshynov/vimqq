if exists('g:autoloaded_vimqq_fmt_ui')
    finish
endif

let g:autoloaded_vimqq_fmt_ui = 1

let s:TIME_FORMAT = "%H:%M"

" tool output longer than 400 bytes will be hidden in fold
" we are not using line count to capture the case when it is one extremely
" long line, which will make chat hard to read.
let s:TOOL_FOLD_LIMIT = 400

function! s:fmt_local_message(message) abort
    let new_msg = { 
        \ 'timestamp' : a:message['timestamp'],
        \ 'bot_name' : '',
        \ 'author' : get(a:message, 'type', 'info') . ': ',
        \ 'text' : a:message['content']
    \ }
    return new_msg
endfunction

function! s:message_text(message) abort
    let prompt = vimqq#prompts#pick(a:message, v:true)
    return vimqq#prompts#apply(a:message, prompt)
endfunction

function! s:fmt_tool_result(message, new_msg) abort
    let text = a:message.content[0].content
    let msg = a:new_msg
    if len(text) >= s:TOOL_FOLD_LIMIT
        let msg.text = "\n\n{{{ [tool_call_result]\n" . text . "\n}}}\n\n"
    else
        let msg.text = "\n\n[tool_call_result]\n" . text . "\n\n"
    endif
    let msg.author = 'tool: @' . a:message['bot_name'] . " " 
    return msg
endfunction


function! vimqq#fmt_ui#for_ui(message) abort
    if a:message['role'] ==# 'local'
        return s:fmt_local_message(a:message)
    endif
    let new_msg = { 
        \ 'timestamp' : a:message['timestamp'],
        \ 'bot_name' : a:message['bot_name']
    \ }

    if a:message['role'] ==# 'user'
        let new_msg['author'] = 'You: @' . a:message['bot_name'] . " "
    else
        let new_msg['author'] = new_msg['bot_name'] . ": "
    endif

    if has_key(a:message, 'content')
        if a:message.content[0].type ==# 'tool_result'
            return s:fmt_tool_result(a:message, new_msg)
        endif
    endif

    let new_msg.text = s:message_text(a:message)
    return new_msg
endfunction

function! vimqq#fmt_ui#ui(message) abort
    if has_key(a:message, 'v2')
        let msg = vimqq#msg_render#render(a:message)
    else
        let msg = vimqq#fmt_ui#for_ui(a:message)
    endif
    let tstamp = "        "
    if has_key(msg, 'timestamp')
        let tstamp = strftime(s:TIME_FORMAT . " ", msg['timestamp'])
    endif
    let prompt = tstamp . msg['author']
    return split(prompt . msg['text'], '\n')
endfunction
