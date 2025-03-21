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
        \ 'matrix' : {},
        \ 'index'  : 0
    \ }

    function! rf.on_files(files) dict
        for f1 in a:files
            for f2 in a:files
                if f1 ==# f2
                    continue
                endif
                let key = f1 . ',' . f2
                let self.matrix[key] = get(self.matrix, key, 0) + 1
            endfor
        endfor
        call vimqq#log#debug(string(self.matrix))
        " So that we continue traversal
        return v:true
    endfunction

    function! rf.start() dict
        let self.crawler = vimqq#indexing#git_history#traverse(
            \ self.git_root, 
            \ {ch, files -> self.on_files(files)},
            \ {cp -> self.on_complete(self.matrix)}
        \)
    endfunction

    call rf.start()

    return rf
endfunction
