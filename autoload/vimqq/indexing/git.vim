" Copyright 2025 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_indexing_git')
    finish
endif

let g:autoloaded_vimqq_indexing_git = 1

" Method to get list of all files in the project using git ls-files
" Uses asynchronous execution for large directories
" Stores the result in the indexer's 'files' member variable
" Implements queue-like behavior with deduplication
function! vimqq#indexing#git#get_files(indexer, ...)
    " Check if we have a project root
    let project_root = a:indexer.get_project_root()
    if project_root is v:null
        call vimqq#log#error('Cannot get git files: no .vqq directory found')
        return 0
    endif
    
    " Go to parent directory of .vqq (actual project root)
    let git_root = fnamemodify(project_root, ':h')
    
    " Don't clear the files list - it's now a queue
    " Only initialize if it doesn't exist yet
    if !exists('a:indexer.files_set')
        let a:indexer.files_set = {}
    endif
    
    " Store reference to indexer for closure
    let indexer_ref = a:indexer
    let CallbackFn = a:0 > 0 && type(a:1) == v:t_func ? a:1 : v:null
    
    " Define output callback
    function! s:on_git_files_output(channel, output) closure
        " Split the output into lines and add to files list if not already present
        let file_list = split(a:output, "\n")
        for file in file_list
            if !empty(file) && !has_key(indexer_ref.files_set, file)
                " Add to queue
                call add(indexer_ref.files, file)
                " Mark as seen in our lookup dict
                let indexer_ref.files_set[file] = 1
            endif
        endfor
    endfunction
    
    " Define exit callback
    function! s:on_git_files_exit(job, status) closure
        if a:status == 0
            call vimqq#log#info('Git files indexed: ' . len(indexer_ref.files) . ' files found')
            
            " Call the callback if provided
            if CallbackFn isnot v:null
                call CallbackFn(indexer_ref.files)
            endif
        else
            call vimqq#log#error('Failed to get git files. Exit status: ' . a:status)
        endif
    endfunction
    
    " Configure the job
    let job_config = {
        \ 'cwd': git_root,
        \ 'out_cb': function('s:on_git_files_output'),
        \ 'exit_cb': function('s:on_git_files_exit'),
        \ 'err_cb': {channel, msg -> vimqq#log#error('Git ls-files error: ' . msg)}
    \ }
    
    " Run the git command asynchronously
    let cmd = ['git', 'ls-files', '--cached', '--others', '--exclude-standard']
    return vimqq#platform#jobs#start(cmd, job_config)
endfunction