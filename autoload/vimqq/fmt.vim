if exists('g:autoloaded_vimqq_fmt')
    finish
endif

let g:autoloaded_vimqq_fmt = 1

let s:template_selection = 
      \ "Here's a code snippet: \n\n{vqq_selection}\n\n{vqq_message}"

let s:template_extra = 
      \  "Here's a code snippet: \n\n{vqq_selection}\n\n"
      \ ."Here's some extra context: \n\n{vqq_context}\n\n{vqq_message}"

let g:vqq_template_selection =
      \ get(g:, 'vqq_template_selection', s:template_selection)
let g:vqq_template_extra     =
      \ get(g:, 'vqq_template_extra', s:template_extra)

" receives message object. Picks the format based on selection/context
" We try to keep the message itself in the very end to allow for more
" effective warmup. 
"
" returns formatted content
function! vimqq#fmt#content(message, folding_context=v:false)
    let l:replacements = {
        \ "message"  : "{vqq_message}",
        \ "selection": "{vqq_selection}",
        \ "context"  : "{vqq_context}"
    \ }

    let l:res = "{vqq_message}"

    let l:templates = [
        \ ["context"   , g:vqq_template_extra],
        \ ["selection" , g:vqq_template_selection]
    \ ]

    " pick the widest context
    for [key, template] in l:templates
        if has_key(a:message, key)
            let l:res = template
            break
        endif
    endfor

    if a:folding_context
        let l:res = substitute(
              \ l:res,
              \ "{vqq_context}",
              \ "{{{ ...\n{vqq_context}\n}}}", 'g')
    endif


    for [key, pattern] in items(l:replacements)
        if has_key(a:message, key)
            let l:res = substitute(l:res, pattern, a:message[key], 'g')
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
