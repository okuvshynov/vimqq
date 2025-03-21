if exists('g:autoloaded_vimqq_indexing_related_files')
    finish
endif

let g:autoloaded_vimqq_indexing_related_files = 1

" TODO: not implemented 
let s:DECAY = 0.01

function! vimqq#indexing#related_files#run(git_root, OnComplete)
    let rf = {
        \ 'git_root' : a:git_root,
        \ 'on_complete' : a:OnComplete,
        \ 'graph' : {},
        \ 'index'  : 0
    \ }

    function! rf.add_edge(f1, f2) dict
        let A = get(self.graph, a:f1, {})
        " 1 should be decayed
        let A[a:f2] = get(A, a:f2, 0) + 1
        let self.graph[a:f1] = A
    endfunction

    function! rf.on_files(files) dict
        call vimqq#log#debug('files: ' . string(a:files))
        for f1 in a:files
            if !filereadable(self.git_root . '/' . f1)
                continue
            endif
            for f2 in a:files
                if !filereadable(self.git_root . '/' . f2)
                    continue
                endif
                if f1 ==# f2
                    continue
                endif
                call self.add_edge(f1, f2)
            endfor
        endfor
        " So that we continue traversal
        return v:true
    endfunction

    function! rf.start() dict
        let self.crawler = vimqq#indexing#git_history#traverse(
            \ self.git_root, 
            \ {ch, files -> self.on_files(files)},
            \ {cp -> self.on_complete(self.graph)}
        \)
    endfunction

    call rf.start()

    return rf
endfunction
