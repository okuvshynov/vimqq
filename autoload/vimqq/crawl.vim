if exists('g:autoloaded_vimqq_crawl')
    finish
endif

let g:autoloaded_vimqq_crawl = 1

" 
" root : root directory to start crawl from
" conf : list of patterns of files to include in the crawl. 
"        Example: ["*.vim", "*.py", "*.txt", "*.md"]
" current_index: map of file path (relative to root) to a structure with
"                checksum and result of ProcFn(file_path)
"                Example: {
"                   "foo/bar.txt": {"checksum": 123, "data": "... bar ..."},
"                   "foo/baz.txt": {"checksum": 234, "data": "... baz ..."},
"                }
"
" Returns new index structure formatted the same way. Construction logic:
"   * Walks over all files in root which match conf
"   * If old checksum equals new checksum, reuse old data
"   * If old checksum is different or there's no entry in index for that file,
"       call ProcFn
function! vimqq#crawl#run(root, conf, current_index, ProcFn, CompleteFn) abort
    let new_index = {}
    
    " TODO: this might be not very efficient
    " Get all files matching patterns
    let all_files = []
    for pattern in a:conf
        let glob_pattern = a:root . '/**/' . pattern
        let matched_files = glob(glob_pattern, 0, 1)
        call extend(all_files, matched_files)
    endfor

    let wait_for = 0
    let all_enqueued = v:false
    let returned = v:false
    let CompleteFn = a:CompleteFn

    function! OnProcFnDone(file_rel_path, data) closure
        let new_index[a:file_rel_path]['data'] = a:data
        let wait_for -= 1
        if wait_for == 0 && all_enqueued && !returned
            let returned = v:true
            call timer_start(0, { -> call(CompleteFn, [new_index])})
            "call call(CompleteFn, [new_index])
        endif
    endfunction

    " Process each file
    for file in all_files
        " Get relative path from root
        let rel_path = substitute(file, '^' . a:root . '/', '', '')
        
        " Calculate checksum using sha256
        let file_content = join(readfile(file), "\n")
        let checksum = sha256(file_content)
        
        " Check if file exists in current index with same checksum
        if has_key(a:current_index, rel_path) && get(a:current_index[rel_path], 'checksum', '') ==# checksum
            " Reuse old data
            let new_index[rel_path] = a:current_index[rel_path]
        else
            " Process new/changed file
            let wait_for += 1
            let new_index[rel_path] = {
                        \ 'checksum': checksum,
            \ }

            call call(a:ProcFn, [rel_path, function('OnProcFnDone')])
        endif
    endfor

    let all_enqueued = v:true

    if wait_for == 0 && all_enqueued && !returned
        let returned = v:true
        call timer_start(0, { -> call(CompleteFn, [new_index])})
    endif
endfunction
