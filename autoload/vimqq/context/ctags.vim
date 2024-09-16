" Copyright 2024 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_ctx_ctags')
    finish
endif

let g:autoloaded_vimqq_ctx_ctags = 1

function! s:_escape_search_pattern(pattern)
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


" Get file referenced in ctags
function! s:_get_relevant_ctx(word)
    let l:taglist = taglist('^' . a:word . '$')
    if empty(l:taglist)
        let l:taglist = taglist('^' . a:word)
    endif

    if empty(l:taglist)
        return ["", []]
    endif

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
        silent! execute s:_escape_search_pattern(l:tag.cmd)
        let l:lnum = line('.')
        silent! execute 'buffer ' . l:saved_buf
        call winrestview(l:saved_view)
    endif

    silent call bufload(l:buf)
    return [l:tag.filename, join(getbufline(l:buf, 1, '$'), "\n")]
endfunction

function! vimqq#context#ctags#run(selection)
    let l:words = split(a:selection, '\W\+')
    let l:res = []
    let l:included = {}
    for word in l:words
        let [file, lines] = s:_get_relevant_ctx(word)
        if !empty(lines) && !has_key(l:included, file)
            call vimqq#log#info('including ' . word . ' -> ' . file . ' to context')
            call add(l:res, "///// FILE: " . file . " /////")
            call add(l:res, lines)
            let l:included[file] = 1
        endif
    endfor 
    return join(l:res, "\n")
endfunction

