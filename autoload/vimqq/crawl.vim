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
    let l:new_index = {}
    
    " TODO: this might be not very efficient
    " Get all files matching patterns
    let l:all_files = []
    for l:pattern in a:conf
        let l:glob_pattern = a:root . '/**/' . l:pattern
        let l:matched_files = glob(l:glob_pattern, 0, 1)
        call extend(l:all_files, l:matched_files)
    endfor

    " Process each file
    for l:file in l:all_files
        " Get relative path from root
        let l:rel_path = substitute(l:file, '^' . a:root . '/', '', '')
        
        " Calculate checksum using sha256
        let l:file_content = join(readfile(l:file), "\n")
        let l:checksum = sha256(l:file_content)
        
        " Check if file exists in current index with same checksum
        if has_key(a:current_index, l:rel_path) && get(a:current_index[l:rel_path], 'checksum', '') ==# l:checksum
            " Reuse old data
            let l:new_index[l:rel_path] = a:current_index[l:rel_path]
        else
            " Process new/changed file
            let l:new_index[l:rel_path] = {
                        \ 'checksum': l:checksum,
                        \ 'data': call(a:ProcFn, [l:file])
                        \ }
        endif
    endfor

    call call(a:CompleteFn, [l:new_index])
endfunction
