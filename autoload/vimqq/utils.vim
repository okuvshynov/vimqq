if exists('g:autoloaded_vimqq_utils')
    finish
endif

let g:autoloaded_vimqq_utils = 1

let s:n_jobs_cleanup = 32
let s:active_jobs    = []

" async jobs management
function! vimqq#utils#keep_job(job)
    let s:active_jobs += [a:job]
    if len(s:active_jobs) > s:n_jobs_cleanup
        for job in s:active_jobs[:]
            if job_info(job)['status'] == 'dead'
                call remove(s:active_jobs, index(s:active_jobs, job))
            endif
        endfor
    endif
endfunction

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

function! vimqq#utils#expand_context(selection, n_first, n_up, n_down)
    let l:words = split(a:selection, '\W\+')
    let l:res = []
    for word in l:words
        let lines = s:get_relevant_ctx(word, a:n_up, a:n_down)
        if !empty(lines)
            call add(l:res, lines)
            if len(l:res) >= a:n_first
                break
            endif
        endif
    endfor 
    return join(l:res, "\n")
endfunction
