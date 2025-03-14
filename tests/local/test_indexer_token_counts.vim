let s:suite = themis#suite('test_indexer_token_counts')
let s:assert = themis#helper('assert')

let s:serv_path = expand('<sfile>:p:h:h') . '/mocks/mock_llama_cpp.py'
let s:skip_all = v:false

" Function to normalize paths (resolves symlinks)
function! s:normalize_path(path)
    " Use the built-in resolve() function to follow symlinks
    return resolve(a:path)
endfunction

function s:on_mock(server_job)
    let s:server_job = a:server_job
endfunction

function s:suite.before()
    let python_cmd = vimqq#util#has_python()
    if python_cmd ==# ''
        let s:skip_all = v:true
        let s:skip_msg = 'python not found or flask package not installed'
        return
    endif
    let s:success = vimqq#platform#jobs#start(
        \ [python_cmd, s:serv_path, '--port', '8888', '--logs', '/tmp/'],
        \ {'on_job': {job -> s:on_mock(job)}}
    \ )
    execute 'sleep 1'
endfunction

function s:suite.after()
    if !s:skip_all
        call job_stop(s:server_job)
    endif
endfunction

function! s:suite.before_each()
    " Create a test directory with a .vqq folder
    let s:test_dir = s:normalize_path(tempname())
    let s:vqq_dir = s:test_dir . '/.vqq'
    let s:index_file = s:vqq_dir . '/index.json'
    
    " Create directory structure
    call mkdir(s:test_dir, 'p')
    call mkdir(s:vqq_dir, 'p')
    
    " Save original directory
    let s:original_dir = getcwd()
    
    " Change to the test directory
    execute 'cd ' . s:test_dir
    
    " Initialize git repository
    call system('git init')
    
    " Create some test files with varying content
    call writefile(['test content for file 1'], 'file1.txt')
    call writefile(['longer test content for file 2 with more tokens'], 'file2.txt')
    call mkdir('subdir', 'p')
    call writefile(['test content in subdir'], 'subdir/file3.txt')
    
    " Add files to git
    call system('git add file1.txt file2.txt subdir/file3.txt')
    
    " Verify that g:vqq_indexer_addr is set, default to localhost if not
    if !exists('g:vqq_indexer_addr')
        let g:vqq_indexer_addr = 'http://localhost:8000'
    endif
    
    " Create an empty index.json file
    call writefile([json_encode({})], s:index_file)
endfunction

function! s:suite.after_each()
    " Return to original directory
    execute 'cd ' . s:original_dir
    
    " Clean up test directories
    call delete(s:test_dir, 'rf')
endfunction

function! s:suite.test_process_token_counts()
    " Create indexer instance for the test directory
    let indexer = vimqq#indexer#new(s:test_dir)
    
    " Set up variables to track the completion of the async job
    let s:git_files_completed = 0
    let s:token_count_completed = 0
    let s:processed_count = 0

    " Define callback for token count completion
    function! s:OnTokenCountComplete(count) closure
        let s:token_count_completed = 1
        let s:processed_count = a:count
    endfunction
        
    
    " Define callback for git files completion
    function! s:OnGitFilesComplete(files) closure
        let s:git_files_completed = 1
        
        " Process token counts for up to 10 files
        call indexer.process_token_counts(10, function('s:OnTokenCountComplete'))
    endfunction
    
    " First, get the git files
    call indexer.get_git_files(function('s:OnGitFilesComplete'))
    
    " Wait for the git files async job to complete (with timeout)
    let timeout = 5000 " 5 seconds
    let start_time = reltime()
    while s:git_files_completed == 0
        " Check for timeout
        if str2float(reltimestr(reltime(start_time))) * 1000 > timeout
            call s:assert.fail('Async git_files operation timed out')
            break
        endif
        sleep 100m
    endwhile
    
    " Verify the git files operation completed
    call s:assert.true(s:git_files_completed, 'Git files operation should complete')
    
    " Wait for the token count async job to complete (with timeout)
    let start_time = reltime()
    while s:token_count_completed == 0
        " Check for timeout
        if str2float(reltimestr(reltime(start_time))) * 1000 > timeout
            call s:assert.fail('Async token_count operation timed out')
            break
        endif
        sleep 100m
    endwhile
    
    " Verify the token count operation completed
    call s:assert.true(s:token_count_completed, 'Token count operation should complete')
    
    " Verify that files were processed
    call s:assert.true(s:processed_count > 0, 'Should process at least one file')
    
    " Read the index file and verify token counts were written
    let index_data = indexer.read_index()
    call vimqq#log#info(string(index_data))
    
    call s:assert.equals(get(index_data, 'file1.txt', 0), 5)
    call s:assert.equals(get(index_data, 'file2.txt', 0), 9)
    call s:assert.equals(get(index_data, 'subdir/file3.txt', 0), 4)
endfunction

function! s:suite.test_process_token_counts_empty_queue()
    " Create indexer instance for the test directory
    let indexer = vimqq#indexer#new(s:test_dir)
    
    " Process token counts without filling the queue first
    let result = indexer.process_token_counts(10)
    
    " Verify that the function returns 0 (no files processed)
    call s:assert.equals(result, 0, 'Should return 0 when queue is empty')
endfunction

function! s:suite.test_process_token_counts_no_project_root()
    " Create a temp directory without .vqq
    let temp_dir = tempname()
    call mkdir(temp_dir, 'p')
    
    " Create an indexer instance with the temp directory
    let indexer = vimqq#indexer#new(temp_dir)
    
    " Process token counts
    let result = indexer.process_token_counts(10)
    
    " Verify that the function returns -1 (error)
    call s:assert.equals(result, -1, 'Should return -1 when no project root found')
    
    " Clean up
    call delete(temp_dir, 'rf')
endfunction
