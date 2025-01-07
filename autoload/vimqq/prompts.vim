" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_prompts_module')
    finish
endif

let g:autoloaded_vimqq_prompts_module = 1

function! vimqq#prompts#gen_title_prompt() abort
    " This prompt is used by all bots to generate a title from a message
    return "Write a title with a few words summarizing the following paragraph. Reply only with title itself. Use no quotes around it.\n\n"
endfunction

" special case for llama which needs different wording
function! vimqq#prompts#gen_llama_title_prompt() abort
    return "Do not answer question above. Instead, write title with a few words summarizing the text. Reply only with title itself. Use no quotes around it.\n\n"
endfunction

function! vimqq#prompts#pick(message, for_ui=v:false)
    let filename = 'prompt'
    if has_key(a:message, 'context')
        let filename = filename . '_context'
    endif
    if has_key(a:message, 'index')
        let filename = filename . '_index'
    endif
    if a:for_ui
        let filename = filename . '_ui'
    endif
    let filename = filename . '.txt'

    let l:root_dir = expand('<script>:p:h:h:h')
    let l:prompt_file = l:root_dir . '/prompts/' . filename
    return join(readfile(l:prompt_file), "\n")
endfunction

