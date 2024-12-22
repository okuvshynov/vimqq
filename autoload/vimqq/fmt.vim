if exists('g:autoloaded_vimqq_fmt')
    finish
endif

let g:autoloaded_vimqq_fmt = 1

" Fill context into message object
function! vimqq#fmt#fill_context(message, context)
    let l:message = deepcopy(a:message)

    if a:context is v:null
        return l:message
    endif
    let l:message.context = a:context
    return l:message
endfunction

let s:template_context = 
      \  "Here's a code snippet: \n\n{vqq_context}\n\n{vqq_message}"

let g:vqq_template_context =
      \ get(g:, 'vqq_template_context', s:template_context)

" receives message object. Picks the format based on selection/context
" We try to keep the message itself in the very end to allow for more
" effective warmup. 
"
" returns formatted content
function! vimqq#fmt#content(message, folding_context=v:false)
    let l:replacements = {
        \ "message"  : "{vqq_message}",
        \ "context"  : "{vqq_context}"
    \ }

    let l:res = "{vqq_message}"

    if has_key(a:message, "context")
        let l:res = g:vqq_template_context
    endif

    if a:folding_context
        let l:res = substitute(
              \ l:res,
              \ "{vqq_context}",
              \ "{{{ ...\n{vqq_context}\n}}}", 'g')
    endif


    for [key, pattern] in items(l:replacements)
        if has_key(a:message, key)
            let l:escaped = a:message[key]
            " TODO: why did I have this?
            "let l:escaped = escape(a:message[key], '/\' . (&magic ? '&~' : ''))
            let l:res = substitute(l:res, pattern, l:escaped, 'g')
        endif
    endfor

    return l:res
endfunction

function! vimqq#fmt#one(message, folding_context=v:false)
    let new_msg = deepcopy(a:message)
    let new_msg.content = vimqq#fmt#content(a:message, a:folding_context)
    return new_msg
endfunction

function! vimqq#fmt#many(messages, folding_context=v:false)
    let new_messages = []
    for msg in a:messages
        call add(new_messages, vimqq#fmt#one(msg, a:folding_context))
    endfor
    return new_messages
endfunction
