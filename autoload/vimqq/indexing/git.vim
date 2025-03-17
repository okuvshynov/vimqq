" Copyright 2025 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_indexing_git')
    finish
endif

let g:autoloaded_vimqq_indexing_git = 1

let s:PERIOD_MS = 30000

function! vimqq#indexing#git#get_files(git_root, OnFile, OnComplete = v:null)
    let crawler = {
        \ 'on_file' : a:OnFile,
        \ 'on_complete' : a:OnComplete,
        \ 'files_read' : 0 
    \ }
    
    " Define output callback
    function! crawler.on_git_files_output(channel, output) dict
        let file_list = split(a:output, "\n")
        for file in file_list
            if !empty(file)
                let self.files_read += 1
                call self.on_file(file)
            endif
        endfor
    endfunction
    
    " Define exit callback
    function! crawler.on_git_files_exit(job, status) dict
        if a:status == 0
            if self.on_complete isnot v:null
                call self.on_complete(self.files_read)
            endif
        else
            call vimqq#log#error('Failed to get git files. Exit status: ' . a:status)
        endif
    endfunction
    
    " Configure the job
    let crawler.job_config = {
        \ 'cwd': a:git_root,
        \ 'out_cb': {c, o -> crawler.on_git_files_output(c, o)},
        \ 'exit_cb': {job, status -> crawler.on_git_files_exit(job, status)},
        \ 'err_cb': {channel, msg -> vimqq#log#error('Git ls-files error: ' . msg)}
    \ }
    
    " Run the git command asynchronously
    let cmd = ['git', 'ls-files', '--cached', '--others', '--exclude-standard']
    return vimqq#platform#jobs#start(cmd, crawler.job_config)
endfunction

function! vimqq#indexing#git#start(git_root, OnFile)
    let git = {
        \ 'git_root' : a:git_root,
        \ 'on_file'  : a:OnFile
    \ }

    function git.next() dict
        call vimqq#indexing#git#get_files(
                    \ self.git_root, 
                    \ {f -> self.on_file(f)},
                    \ {fc -> self.schedule(s:PERIOD_MS)}
        \)
    endfunction

    function git.schedule(period_ms) dict
        call timer_start(a:period_ms, {t -> self.next()})
    endfunction

    call git.next()
    return git
endfunction
