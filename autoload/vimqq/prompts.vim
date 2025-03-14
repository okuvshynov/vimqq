" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_prompts_module')
    finish
endif

let g:autoloaded_vimqq_prompts_module = 1

function! vimqq#prompts#gen_title_prompt(message) abort
    let text = vimqq#prompts#apply(a:message, vimqq#prompts#pick_title(a:message))
    " This prompt is used by all bots to generate a title from a message
    return "Write a title with a few words summarizing the following paragraph. Reply only with title itself. Use no quotes around it.\n\n" . text
endfunction

function! vimqq#prompts#indexing_file() abort
    let root_dir = vimqq#util#root()
    let prompt_file = root_dir . '/prompts/indexing_file.txt'
    return join(readfile(prompt_file), "\n")
endfunction

function! vimqq#prompts#reviewer_prompt() abort
    let root_dir = vimqq#util#root()
    let prompt_file = root_dir . '/prompts/reviewer_prompt.txt'
    return join(readfile(prompt_file), "\n")
endfunction

" never send index to title gen
function! vimqq#prompts#pick_title(message)
    let filename = 'prompt'
    if has_key(a:message.sources, 'context')
        let filename = filename . '_context'
    endif
    let filename = filename . '.txt'

    let root_dir = vimqq#util#root()
    let prompt_file = root_dir . '/prompts/' . filename
    return join(readfile(prompt_file), "\n")
endfunction

function! vimqq#prompts#pick(message, for_ui=v:false)
    let filename = 'prompt'
    if has_key(a:message.sources, 'context')
        let filename = filename . '_context'
    endif
    if has_key(a:message.sources, 'index')
        let filename = filename . '_index'
    endif
    if a:for_ui
        let filename = filename . '_ui'
    endif
    let filename = filename . '.txt'

    let root_dir = vimqq#util#root()
    let prompt_file = root_dir . '/prompts/' . filename
    return join(readfile(prompt_file), "\n")
endfunction

function! vimqq#prompts#apply(message, prompt)
    let replacements = {
        \ "{vqq_message}": {msg -> has_key(msg.sources, 'text') ? msg.sources.text : ''},
        \ "{vqq_context}": {msg -> has_key(msg.sources, 'context') ? msg.sources.context : ''},
        \ "{vqq_lucas_index}": {msg -> has_key(msg.sources, 'index') ? msg.sources.index : ''},
        \ "{vqq_lucas_index_size}": {msg -> has_key(msg.sources, 'index') ? len(msg.sources.index) : 0},
    \ }

    let res = a:prompt
    for [pattern, ContextFn] in items(replacements)
        let escaped = escape(ContextFn(a:message), (&magic ? '&~' : ''))
        let res = substitute(res, pattern, escaped, 'g')
    endfor

    return res
endfunction
