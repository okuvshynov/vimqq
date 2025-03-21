" Copyright 2025 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_indexing_git_history')
    finish
endif

let g:autoloaded_vimqq_indexing_git_history = 1

let s:COMMIT_LIMIT  = 100
let s:READ_DELAY_MS = 100 

function! vimqq#indexing#git_history#file_reader(git_root, commit_id, OnComplete)
    let reader = {
        \ 'git_root'    : a:git_root,
        \ 'on_complete' : a:OnComplete,
        \ 'commit_id'   : a:commit_id,
        \ 'files'       : []
    \ }

    function! reader.on_output(channel, output) dict
        let file_list = split(a:output, "\n")
        call filter(file_list, 'v:val != ""')
        for file_path in file_list
            call add(self.files, file_path)
        endfor
    endfunction

    function! reader.on_exit(job, status) dict
        if a:status != 0
            call vimqq#log#error('Failed to get files for commit ' . self.commit_id . '. Exit status: ' . a:status)
        endif

        call self.on_complete(self.commit_id, self.files)
    endfunction

    function! reader.start() dict
        " Configure job for getting files changed in this commit
        let job_config = {
            \ 'cwd': self.git_root,
            \ 'out_cb': {c, o -> self.on_output(c, o)},
            \ 'exit_cb': {job, status -> self.on_exit(job, status)},
            \ 'err_cb': {channel, msg -> vimqq#log#error('Git show error for commit ' . self.commit_id . ': ' . msg)}
        \ }
        
        " Run git command to get files changed in this commit
        let cmd = ['git', 'show', '--pretty=', '--name-only', self.commit_id]
        return vimqq#platform#jobs#start(cmd, job_config)
    endfunction

    return reader
endfunction

function! vimqq#indexing#git_history#traverse(git_root, OnCommit, OnComplete = v:null)
    let traverser = {
        \ 'git_root': a:git_root,
        \ 'on_commit': a:OnCommit,
        \ 'on_complete': a:OnComplete,
        \ 'commits_processed': 0,
        \ 'current_commit': '',
        \ 'continue_traversal': v:true,
        \ 'commit_hashes': []
    \ }
    
    " First, get list of all commit hashes in chronological order
    function! traverser.start() dict
        " Configure the job for getting commit hashes
        let self.job_config = {
            \ 'cwd': self.git_root,
            \ 'out_cb': {c, o -> self.on_commits_output(c, o)},
            \ 'exit_cb': {job, status -> self.on_commits_exit(job, status)},
            \ 'err_cb': {channel, msg -> vimqq#log#error('Git log error: ' . msg)}
        \ }
        
        " Run git command to get commit hashes
        let cmd = ['git', '--no-pager', 'log', '--format=%H', '-n', s:COMMIT_LIMIT]
        return vimqq#platform#jobs#start(cmd, self.job_config)
    endfunction
    
    " Process commit hashes output
    function! traverser.on_commits_output(channel, output) dict
        let commit_hashes = split(a:output, "\n")
        call filter(commit_hashes, 'v:val != ""')
        for commit in commit_hashes
            call add(self.commit_hashes, commit)
        endfor
    endfunction
    
    " When commit list is complete, start processing each commit
    function! traverser.on_commits_exit(job, status) dict
        if a:status != 0
            call vimqq#log#error('Failed to get commit history. Exit status: ' . a:status)
            if self.on_complete isnot v:null
                call self.on_complete(self.commits_processed)
            endif
            return
        endif
        
        if empty(self.commit_hashes)
            call vimqq#log#info('No commits found in the repository')
            if self.on_complete isnot v:null
                call self.on_complete(self.commits_processed)
            endif
            return
        endif
        
        " Start processing the first commit
        call self.process_next_commit()
    endfunction

    function! traverser.on_commit_files(commit_id, files) dict
        let self.continue_traversal = self.on_commit(a:commit_id, a:files)
        call self.process_next_commit()
    endfunction
    
    " Process commits one by one
    function! traverser.process_next_commit() dict
        if !self.continue_traversal || empty(self.commit_hashes)
            " Traversal is complete or was stopped
            call vimqq#log#debug('on_complete')
            if self.on_complete isnot v:null
                call self.on_complete(self.commits_processed)
            endif
            return
        endif
        
        " Get the next commit hash
        let commit_id = remove(self.commit_hashes, 0)

        let reader = vimqq#indexing#git_history#file_reader(self.git_root, commit_id, {c, f -> self.on_commit_files(c, f)})
        call timer_start(s:READ_DELAY_MS, {t -> reader.start()})

    endfunction
    
    " Start the traversal
    call traverser.start()
    return traverser
endfunction
