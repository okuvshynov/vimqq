" Copyright 2024 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_context')
    finish
endif

let g:autoloaded_vimqq_context = 1

function! vimqq#context#context#fill(message, context)
    let l:message = deepcopy(a:message)

    if a:context is v:null
        return l:message
    endif
    let l:message.context = a:context
    return l:message
endfunction
