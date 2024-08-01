" Copyright 2024 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_context')
    finish
endif

let g:autoloaded_vimqq_context = 1

let g:vqq_exp_context_n_tags = get(g:, 'vqq_exp_context_n_tags', 10)
let g:vqq_exp_context_n_up   = get(g:, 'vqq_exp_context_n_up', 10)
let g:vqq_exp_context_n_down = get(g:, 'vqq_exp_context_n_down', 50)


function! s:escape_search_pattern(pattern)
    " Remove leading and trailing delimiters if present
    let pattern = a:pattern
    if pattern[0] == '/' && pattern[len(pattern) - 1] == '/'
        let pattern = pattern[1:len(pattern) - 2]
    endif

    " Escape special characters, but handle ^ and $ separately
    let escaped = ''
    let i = 0
    while i < len(pattern)
        if i == 0 && pattern[i] == '^'
            let escaped .= '^'
        elseif i == len(pattern) - 1 && pattern[i] == '$'
            let escaped .= '$'
        elseif pattern[i] =~ '[*.\[\]^$]'
            let escaped .= '\' . pattern[i]
        else
            let escaped .= pattern[i]
        endif
        let i += 1
    endwhile

    " Add delimiters back
    return '/' . escaped . '/'
endfunction

" extra context management.
" currently using ctags + naive heuristic

" This is not very good. It just gets N lines down, M lines up to fetch
" potential comments.
function! s:get_relevant_ctx(word, n_up, n_down)
    let l:taglist = taglist('^' . a:word . '$')
    if empty(l:taglist)
        let l:taglist = taglist('^' . a:word)
    endif

    if empty(l:taglist)
        return []
    endif

    " TODO: is this correct? are we always in the current buffer?
    let l:curbuf = bufnr('%')

    let l:tag = {}
    for l:t in l:taglist
        if bufnr(l:t.filename) == l:curbuf
            let l:tag = l:t
            break
        endif
    endfor
    if empty(l:tag)
        let l:tag = l:taglist[0]
    endif

    " Open the file containing the tag
    let l:buf = bufnr(l:tag.filename)
    if l:buf == -1
        silent execute 'badd ' . l:tag.filename
        let l:buf = bufnr(l:tag.filename)
    endif

    let l:lnum = str2nr(l:tag.cmd)
    " If it's not a line number, it's a search pattern
    if l:lnum == 0  
        let l:saved_view = winsaveview()
        let l:saved_buf = bufnr('%')
        silent! execute 'buffer ' . l:buf
        call cursor(1, 1)
        silent! execute s:escape_search_pattern(l:tag.cmd)
        let l:lnum = line('.')
        silent! execute 'buffer ' . l:saved_buf
        call winrestview(l:saved_view)
    endif

    let l:start = max([1, l:lnum - a:n_up])
    let l:end = l:lnum + a:n_down

    silent call bufload(l:buf)
    return join(getbufline(l:buf, l:start, l:end), "\n")
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

function! vimqq#context#ctags(selection)
    let n_up = g:vqq_exp_context_n_up
    let n_down = g:vqq_exp_context_n_down
    let n_tags = g:vqq_exp_context_n_tags

    let l:words = split(a:selection, '\W\+')
    let l:res = []
    for word in l:words
        let lines = s:get_relevant_ctx(word, n_up, n_down)
        if !empty(lines)
            call add(l:res, lines)
            if len(l:res) >= n_tags
                break
            endif
        endif
    endfor 
    return join(l:res, "\n")
endfunction

function! vimqq#context#file()
    return join(getline(1, '$'), "\n")
endfunction

function! vimqq#context#fill(message, context_modes)
    let l:message = deepcopy(a:message)

    if has_key(a:context_modes, "selection")
        let l:selection = s:get_visual_selection()
        let l:message.selection = l:selection
    endif
    if has_key(a:context_modes, "file")
        let l:message.context = get(l:message, 'context', '') . vimqq#context#file()
    endif
    if has_key(a:context_modes, "ctags")
        let l:source = join([get(l:message, 'selection', ''), get(l:message, 'context', '')], '\n\n')
        let l:message.context = get(l:message, 'context', '') . vimqq#context#ctags(l:source)
    endif
    if has_key(a:context_modes, "project")
        let l:message.context = get(l:message, 'context', '') . vimqq#full_context#get()
    endif
    return l:message
endfunction
