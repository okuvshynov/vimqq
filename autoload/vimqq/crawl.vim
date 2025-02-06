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
function! vimqq#crawl#run(root, conf, current_index, ProcFn) abort

endfunction
