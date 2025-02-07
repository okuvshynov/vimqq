if exists('g:autoloaded_vimqq_crawl')
    finish
endif

let g:autoloaded_vimqq_crawl = 1

" Async function
" TODO: this is messy, we need futures for vimscript
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
" Returns new index structure formatted the same way in CompleteFn. Construction logic:
"   * Walks over all files in root which match conf
"   * If old checksum equals new checksum, reuse old data
"   * If old checksum is different or there's no entry in index for that file,
"       call ProcFn
function! vimqq#crawl#run(root, conf, current_index, ProcFn, CompleteFn) abort
    let new_index = {}

    call vimqq#log#debug('index: root = ' . a:root)
    call vimqq#log#debug('index: conf = ' . string(a:conf))
    
    " TODO: this might be not very efficient
    " Get all files matching patterns
    let all_files = []
    for pattern in a:conf
        let glob_pattern = a:root . '/**/' . pattern
        let matched_files = glob(glob_pattern, 0, 1)
        call extend(all_files, matched_files)
    endfor

    call vimqq#log#debug('index: all_files: ' . string(all_files))

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

function! vimqq#crawl#loop(ProcFn)
    let root = vimqq#util#project_root()
    let conf_path = root . '/.vqq'
    call vimqq#log#debug('index: conf_path = ' . conf_path)
    let index_path = root . '/.vqq_index'
    let conf = []
    let index = {}

    let ProcFn = a:ProcFn

    if filereadable(conf_path)
        let conf_lines = readfile(conf_path)
        let conf = json_decode(join(conf_lines, "\n"))
    endif
    if filereadable(index_path)
        let index_lines = readfile(index_path)
        let index = json_decode(join(index_lines, "\n"))
    endif

    function! OnComplete(new_index) closure
        let index_lines = split(json_encode(a:new_index), "\n")
        call writefile(index_lines, index_path)
        " scheduling next iteration
        call timer_start(60 * 1000, { -> vimqq#crawl#loop(ProcFn)})
    endfunction

    call vimqq#crawl#run(root, conf, index, ProcFn, function('OnComplete'))
endfunction

function! vimqq#crawl#loop_local_indexer()
    let indexer = vimqq#bots#local_indexer#new()
    let ProcFn = {file_path, OnDone -> indexer.enqueue(file_path, OnDone)}
    return vimqq#crawl#loop(ProcFn)
endfunction
