" Copyright 2024 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_context')
    finish
endif

let g:autoloaded_vimqq_context = 1

function! s:_get_file()
    return join(getline(1, '$'), "\n")
endfunction

function! s:get_visual_selection()
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end  , column_end  ] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0]  = lines[0][column_start - 1:]
    return join(lines, "\n")
endfunction

function! vimqq#context#context#fill(message, context_modes)
    let l:message = deepcopy(a:message)

    if has_key(a:context_modes, "selection")
        let l:selection = s:get_visual_selection()
        let l:message.selection = l:selection
    endif
    if has_key(a:context_modes, "file")
        let l:message.context = get(l:message, 'context', '') . s:_get_file()
    endif
    if has_key(a:context_modes, "ctags")
        let l:source = join([get(l:message, 'selection', ''), get(l:message, 'context', '')], '\n\n')
        let l:message.context = get(l:message, 'context', '') . vimqq#context#ctags#run(l:source)
    endif
    if has_key(a:context_modes, "project")
        let l:message.context = get(l:message, 'context', '') . vimqq#context#project#run()
    endif
    if has_key(a:context_modes, "blame")
        let l:message.context = get(l:message, 'context', '') . vimqq#context#blame#run()
    endif
    return l:message
endfunction
