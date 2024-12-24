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