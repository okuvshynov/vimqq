if exists('g:autoloaded_vimqq_fmt_ui')
    finish
endif

let g:autoloaded_vimqq_fmt_ui = 1

let s:TIME_FORMAT = "%H:%M"

" tool output longer than 400 bytes will be hidden in fold
" we are not using line count to capture the case when it is one extremely
" long line, which will make chat hard to read.
let s:TOOL_FOLD_LIMIT = 400

function! vimqq#fmt_ui#for_ui(message) abort
    let new_msg = { 
        \ 'timestamp' : a:message['timestamp'] ,
        \ 'bot_name' : a:message['bot_name']
        \ }

    if a:message['role'] ==# 'user'
        let new_msg['author'] = 'You: @' . a:message['bot_name'] . " "
    else
        let new_msg['author'] = new_msg['bot_name'] . ": "
    endif

    " check if this is tool response
    " currently tool_use is handled in prompt format
    " but tool result is handled here
    if has_key(a:message, 'content')
        if a:message.content[0].type ==# 'tool_result'
            let text = a:message.content[0].content
            if len(text) >= s:TOOL_FOLD_LIMIT
                let new_msg.text = "\n\n{{{ [tool_call_result]\n" . text . "\n}}}\n\n"
            else
                let new_msg.text = "\n\n[tool_call_result]\n" . text . "\n\n"
            endif
            let new_msg.author = 'tool: @' . a:message['bot_name'] . " " 
            return new_msg
        endif
    endif

    let new_msg.text = s:format_message(a:message)
    return new_msg
endfunction

function! s:format_message(message) abort
    let prompt = vimqq#prompts#pick(a:message, v:true)
    return vimqq#prompts#apply(a:message, prompt)
endfunction

function! vimqq#fmt_ui#ui(message) abort
    let msg = vimqq#fmt_ui#for_ui(a:message)
    let tstamp = "        "
    if has_key(msg, 'timestamp')
        let tstamp = strftime(s:TIME_FORMAT . " ", msg['timestamp'])
    endif
    let prompt = tstamp . msg['author']
    " TODO: what if there's more than 1 piece of content?
    return split(prompt . msg['text'], '\n')
endfunction
