" Copyright 2024 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_context')
    finish
endif

let g:autoloaded_vimqq_context = 1

let g:vqq_exp_context_n_tags = get(g:, 'vqq_exp_context_n_tags', 4)
let g:vqq_exp_context_n_up   = get(g:, 'vqq_exp_context_n_up', 4)
let g:vqq_exp_context_n_down = get(g:, 'vqq_exp_context_n_down', 4)

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
        silent execute 'buffer ' . l:buf
        call cursor(1, 1)
        silent execute l:tag.cmd
        let l:lnum = line('.')
        silent execute 'buffer ' . l:saved_buf
        call winrestview(l:saved_view)
    endif

    let l:start = max([1, l:lnum - a:n_up])
    let l:end = l:lnum + a:n_down

    silent call bufload(l:buf)
    return join(getbufline(l:buf, l:start, l:end), "\n")
endfunction

function! vimqq#context#expand(selection)
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

