" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_expand_context')
    finish
endif

let g:autoloaded_vimqq_expand_context = 1

" This is not very good. It just gets N lines down, M lines up to fetch
" potential comments.
function! GetRelevantContext(word, n_up, n_down)
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
        execute 'badd ' . l:tag.filename
        let l:buf = bufnr(l:tag.filename)
    endif

    let l:lnum = str2nr(l:tag.cmd)
    " If it's not a line number, it's a search pattern
    if l:lnum == 0  
        let l:saved_view = winsaveview()
        let l:saved_buf = bufnr('%')
        execute 'buffer ' . l:buf
        call cursor(1, 1)
        execute l:tag.cmd
        let l:lnum = line('.')
        execute 'buffer ' . l:saved_buf
        call winrestview(l:saved_view)
    endif

    let l:start = max([1, l:lnum - a:n_up])
    let l:end = l:lnum + a:n_down

    " Fetch the lines
    return join(getbufline(l:buf, l:start, l:end), '\n')
endfunction

function! vimqq#expand_context(selection, n_first, n_up, n_down)
    let l:words = split(a:selection, '\W\+')
    let l:res = []
    for word in l:words
        let lines = GetRelevantContext(word, n_up, n_down)
        if !empty(lines)
            add(l:res, lines)
            if len(l:res) >= a:n_first
                break
            endif
        endif
    endfor 
    return join(l:res, "\n\n")
endfunction
