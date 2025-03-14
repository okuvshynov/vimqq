let s:suite = themis#suite('test_indexer_git_files')
let s:assert = themis#helper('assert')

" Function to normalize paths (resolves symlinks)
function! s:normalize_path(path)
    " Use the built-in resolve() function to follow symlinks
    return resolve(a:path)
endfunction

function! s:suite.before_each()
    " Create a test directory with a .vqq folder
    let s:test_dir = s:normalize_path(tempname())
    let s:vqq_dir = s:test_dir . '/.vqq'
    
    " Create directory structure
    call mkdir(s:test_dir, 'p')
    call mkdir(s:vqq_dir, 'p')
    
    " Save original directory
    let s:original_dir = getcwd()
    
    " Change to the test directory
    execute 'cd ' . s:test_dir
    
    " Initialize git repository
    call system('git init')
    
    " Create some test files
    call writefile(['test1'], 'file1.txt')
    call writefile(['test2'], 'file2.txt')
    call mkdir('subdir', 'p')
    call writefile(['test3'], 'subdir/file3.txt')
    
    " Add file1.txt to git (tracked file)
    call system('git add file1.txt')
    " Leave file2.txt and subdir/file3.txt untracked
endfunction

function! s:suite.after_each()
    " Return to original directory
    execute 'cd ' . s:original_dir
    
    " Clean up test directories
    call delete(s:test_dir, 'rf')
endfunction

function! s:suite.test_get_git_files()
    " Create indexer instance for the test directory
    let indexer = vimqq#indexer#new(s:test_dir)
    
    " Set up variables to track the completion of the async job
    let s:async_completed = 0
    let s:async_files = []
    
    " Define callback to handle results
    function! OnTestComplete(files) closure
        let s:async_files = a:files
        let s:async_completed = 1
    endfunction
    
    " Call get_git_files with our callback
    call indexer.get_git_files(function('OnTestComplete'))
    
    " Wait for the async job to complete (with timeout)
    let timeout = 5000 " 5 seconds
    let start_time = reltime()
    while s:async_completed == 0
        " Check for timeout
        if str2float(reltimestr(reltime(start_time))) * 1000 > timeout
            call s:assert.fail('Async git_files operation timed out')
            break
        endif
        sleep 100m
    endwhile
    
    " Verify the operation completed
    call s:assert.true(s:async_completed, 'Async operation should complete')
    
    " Verify we found some files
    call s:assert.true(len(s:async_files) >= 2, 'Should find at least 2 files')
    
    " Verify the indexer.files member variable matches the callback results
    call s:assert.equals(len(indexer.files), len(s:async_files), 'indexer.files should match the callback results')
    
    " Check for specific files in the results
    let has_file1 = 0
    let has_file2 = 0
    let has_file3 = 0
    
    for file in s:async_files
        if file ==# 'file1.txt'
            let has_file1 = 1
        elseif file ==# 'file2.txt'
            let has_file2 = 1
        elseif file ==# 'subdir/file3.txt'
            let has_file3 = 1
        endif
    endfor
    
    " Verify all expected files were found
    call s:assert.true(has_file1, 'Should find file1.txt (tracked file)')
    call s:assert.true(has_file2, 'Should find file2.txt (untracked file)')
    call s:assert.true(has_file3, 'Should find subdir/file3.txt (untracked file in subdirectory)')
endfunction

function! s:suite.test_get_git_files_no_project_root()
    " Create a temp directory without .vqq
    let temp_dir = tempname()
    call mkdir(temp_dir, 'p')
    
    " Create an indexer instance with the temp directory
    let indexer = vimqq#indexer#new(temp_dir)
    
    " Call get_git_files and verify it returns 0 (error)
    let result = indexer.get_git_files()
    call s:assert.equals(result, 0)
    
    " Verify files list is empty
    call s:assert.equals(len(indexer.files), 0)
    
    " Clean up
    call delete(temp_dir, 'rf')
endfunction
