let s:suite = themis#suite('test_indexer_queue')
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
    
    " Create some test files for the first run
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

function! s:suite.test_queue_behavior()
    " Create indexer instance for the test directory
    let indexer = vimqq#indexer#new(s:test_dir)
    
    " Set up variables to track the completion of the async job
    let s:async_completed_first = 0
    let s:async_files_first = []
    
    " Define callback to handle results from first run
    function! OnFirstComplete(files) closure
        let s:async_files_first = a:files
        let s:async_completed_first = 1
    endfunction
    
    " Call get_git_files with our callback for first run
    call indexer.get_git_files(function('OnFirstComplete'))
    
    " Wait for the async job to complete (with timeout)
    let timeout = 5000 " 5 seconds
    let start_time = reltime()
    while s:async_completed_first == 0
        " Check for timeout
        if str2float(reltimestr(reltime(start_time))) * 1000 > timeout
            call s:assert.fail('Async git_files operation timed out (first run)')
            break
        endif
        sleep 100m
    endwhile
    
    " Verify the first operation completed
    call s:assert.true(s:async_completed_first, 'First async operation should complete')
    
    " Verify we found some files in the first run
    call s:assert.true(len(s:async_files_first) >= 3, 'Should find at least 3 files in first run')
    
    " Now create some additional files for second run
    call writefile(['test4'], 'file4.txt')
    call writefile(['test5'], 'file5.txt')
    
    " Set up variables to track the completion of the second async job
    let s:async_completed_second = 0
    let s:async_files_second = []
    
    " Define callback to handle results from second run
    function! OnSecondComplete(files) closure
        let s:async_files_second = a:files
        let s:async_completed_second = 1
    endfunction
    
    " Call get_git_files again without clearing the files list (queue behavior)
    call indexer.get_git_files(function('OnSecondComplete'))
    
    " Wait for the second async job to complete (with timeout)
    let start_time = reltime()
    while s:async_completed_second == 0
        " Check for timeout
        if str2float(reltimestr(reltime(start_time))) * 1000 > timeout
            call s:assert.fail('Async git_files operation timed out (second run)')
            break
        endif
        sleep 100m
    endwhile
    
    " Verify the second operation completed
    call s:assert.true(s:async_completed_second, 'Second async operation should complete')
    
    " Check the length of the files queue after both runs
    " Since we added 2 new files in the second run, the queue should have 5 files total
    " (assuming perfect deduplication and no extra files)
    call s:assert.equals(len(indexer.files), 5, 'Queue should contain 5 files after both runs')
    
    " Check for all 5 expected files in the final results
    let has_files = {'file1.txt': 0, 'file2.txt': 0, 'subdir/file3.txt': 0, 'file4.txt': 0, 'file5.txt': 0}
    
    for file in indexer.files
        if has_key(has_files, file)
            let has_files[file] = 1
        endif
    endfor
    
    " Verify all expected files were found
    call s:assert.true(has_files['file1.txt'], 'Queue should contain file1.txt')
    call s:assert.true(has_files['file2.txt'], 'Queue should contain file2.txt')
    call s:assert.true(has_files['subdir/file3.txt'], 'Queue should contain subdir/file3.txt')
    call s:assert.true(has_files['file4.txt'], 'Queue should contain file4.txt')
    call s:assert.true(has_files['file5.txt'], 'Queue should contain file5.txt')
    
    " Verify deduplication by running git_get_files a third time with the same files
    let s:async_completed_third = 0
    
    function! OnThirdComplete(files) closure
        let s:async_completed_third = 1
    endfunction
    
    " Call get_git_files a third time
    call indexer.get_git_files(function('OnThirdComplete'))
    
    " Wait for the third async job to complete
    let start_time = reltime()
    while s:async_completed_third == 0
        if str2float(reltimestr(reltime(start_time))) * 1000 > timeout
            call s:assert.fail('Async git_files operation timed out (third run)')
            break
        endif
        sleep 100m
    endwhile
    
    " Verify queue size hasn't changed after third run (perfect deduplication)
    call s:assert.equals(len(indexer.files), 5, 'Queue size should remain 5 after third run (deduplication)')
endfunction

function! s:suite.test_files_set_initialization()
    " Create indexer instance for the test directory
    let indexer = vimqq#indexer#new(s:test_dir)
    
    " Verify files_set is initialized
    call s:assert.true(exists('indexer.files_set'), 'files_set should be initialized')
    call s:assert.equals(type(indexer.files_set), v:t_dict, 'files_set should be a dictionary')
    
    " Verify files is initialized as an empty list
    call s:assert.equals(type(indexer.files), v:t_list, 'files should be a list')
    call s:assert.equals(len(indexer.files), 0, 'files should start empty')
endfunction
