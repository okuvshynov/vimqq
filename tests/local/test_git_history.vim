let s:suite  = themis#suite('test_git_history.vim')
let s:assert = themis#helper('assert')

" Setup test environment
function! s:suite.before() abort
    let s:temp_dir = tempname()
    let temp_dir = s:temp_dir
    call mkdir(temp_dir)
    
    " Initialize git repo
    call system('cd ' . temp_dir . ' && git init')
    call system('cd ' . temp_dir . ' && git config user.email "test@example.com"')
    call system('cd ' . temp_dir . ' && git config user.name "Test User"')
    
    " Create and commit some files
    call system('cd ' . temp_dir . ' && echo "file1 content" > file1.txt')
    call system('cd ' . temp_dir . ' && git add file1.txt')
    call system('cd ' . temp_dir . ' && git commit -m "Add file1.txt"')
    
    call system('cd ' . temp_dir . ' && echo "file2 content" > file2.txt')
    call system('cd ' . temp_dir . ' && git add file2.txt')
    call system('cd ' . temp_dir . ' && git commit -m "Add file2.txt"')
    
    call system('cd ' . temp_dir . ' && echo "updated content" > file1.txt')
    call system('cd ' . temp_dir . ' && git add file1.txt')
    call system('cd ' . temp_dir . ' && git commit -m "Update file1.txt"')
    
    return temp_dir
endfunction

function! s:suite.after() abort
    call delete(s:temp_dir, 'rf')
endfunction

function! s:suite.test_git_history_traverse() abort
    " Skip if git is not available
    if !executable('git')
        call s:assert.skip('git command not available')
        return
    endif
    
    " Setup test repository
    let temp_dir = s:temp_dir
    let commits_found = []
    let files_changed = {}
    let traversal_complete = 0
    
    " Define callbacks
    function! s:on_commit(commit_hash, files) closure
        call add(commits_found, a:commit_hash)
        let files_changed[a:commit_hash] = a:files
        " Always return true to continue traversal
        return v:true
    endfunction
    
    function! s:on_complete(commits_processed) closure
        let traversal_complete = 1
    endfunction
    
    " Start traversal
    call vimqq#indexing#git_history#traverse(temp_dir, function('s:on_commit'), function('s:on_complete'))
    
    " Wait for traversal to complete (with timeout)
    let timeout = 5000  " 5 seconds
    let start_time = reltime()
    while !traversal_complete && float2nr(reltimefloat(reltime(start_time)) * 1000) < timeout
        sleep 100m
    endwhile
    
    " Verify results
    call s:assert.equals(len(commits_found), 3, 'Should find 3 commits')
    
    " Verify file changes
    let first_commit = commits_found[0]
    let second_commit = commits_found[1]
    let third_commit = commits_found[2]
    
    call s:assert.equals(len(files_changed[first_commit]), 1, 'First commit should have 1 file')
    call s:assert.equals(files_changed[first_commit][0], 'file1.txt', 'First commit should change file1.txt')
    
    call s:assert.equals(len(files_changed[second_commit]), 1, 'Second commit should have 1 file')
    call s:assert.equals(files_changed[second_commit][0], 'file2.txt', 'Second commit should change file2.txt')
    
    call s:assert.equals(len(files_changed[third_commit]), 1, 'Third commit should have 1 file')
    call s:assert.equals(files_changed[third_commit][0], 'file1.txt', 'Third commit should change file1.txt again')
    
endfunction

function! s:suite.test_git_history_early_stop() abort
    " Skip if git is not available
    if !executable('git')
        call s:assert.skip('git command not available')
        return
    endif
    
    " Setup test repository
    let temp_dir = s:temp_dir
    let commits_found = []
    let traversal_complete = 0
    
    " Define callbacks
    function! s:on_commit_stop_early(commit_hash, files) closure
        call add(commits_found, a:commit_hash)
        " Stop after first commit
        return v:false
    endfunction
    
    function! s:on_complete_early(commits_processed) closure
        let traversal_complete = 1
    endfunction
    
    " Start traversal
    call vimqq#indexing#git_history#traverse(temp_dir, function('s:on_commit_stop_early'), function('s:on_complete_early'))
    
    " Wait for traversal to complete (with timeout)
    let timeout = 5000  " 5 seconds
    let start_time = reltime()
    while !traversal_complete && float2nr(reltimefloat(reltime(start_time)) * 1000) < timeout
        sleep 100m
    endwhile
    
    " Verify results
    call s:assert.equals(len(commits_found), 1, 'Should only process 1 commit due to early stop')
endfunction
