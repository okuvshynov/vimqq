let s:suite = themis#suite('test_indexer.vim')
let s:assert = themis#helper('assert')

" Setup test directories

" Function to normalize paths (resolves symlinks)
function! s:normalize_path(path)
    " Use the built-in resolve() function to follow symlinks
    return resolve(a:path)
endfunction

function! s:suite.before_each()
    let s:test_dir = s:normalize_path(tempname())
    let s:vqq_dir = s:test_dir . '/.vqq'
    let s:index_file = s:vqq_dir . '/index.json'
    
    " Create test directory structure
    call mkdir(s:test_dir, 'p')
    call mkdir(s:vqq_dir, 'p')
endfunction

function! s:suite.after_each()
    " Clean up test directories after each test
    call delete(s:test_dir, 'rf')
endfunction

function! s:suite.test_find_project_root_legacy()
    " Change to the test directory
    let original_dir = getcwd()
    execute 'cd ' . s:test_dir
    
    " Test finding project root with legacy function
    let project_root = s:normalize_path(vimqq#indexer#get_project_root())
    call s:assert.equals(project_root, s:normalize_path(s:vqq_dir))
    
    " Return to original directory
    execute 'cd ' . original_dir
endfunction

function! s:suite.test_find_project_root_class()
    " Create an indexer instance with the test directory
    let indexer = vimqq#indexer#new(s:test_dir)
    
    " Test finding project root with class method
    let project_root = s:normalize_path(indexer.get_project_root())
    call s:assert.equals(project_root, s:normalize_path(s:vqq_dir))
    
    " Test with a subdirectory
    let sub_dir = s:test_dir . '/subdir'
    call mkdir(sub_dir, 'p')
    let indexer2 = vimqq#indexer#new(sub_dir)
    let project_root2 = s:normalize_path(indexer2.get_project_root())
    call s:assert.equals(project_root2, s:normalize_path(s:vqq_dir))
endfunction

function! s:suite.test_no_project_root_legacy()
    " Change to temp directory without .vqq
    let temp_dir = tempname()
    call mkdir(temp_dir, 'p')
    let original_dir = getcwd()
    execute 'cd ' . temp_dir
    
    " Test that no project root is found with legacy function
    let project_root = vimqq#indexer#get_project_root()
    call s:assert.equals(project_root, v:null)
    
    " Return to original directory and clean up
    execute 'cd ' . original_dir
    call delete(temp_dir, 'rf')
endfunction

function! s:suite.test_no_project_root_class()
    " Create a temp directory without .vqq
    let temp_dir = tempname()
    call mkdir(temp_dir, 'p')
    
    " Create an indexer instance with the temp directory
    let indexer = vimqq#indexer#new(temp_dir)
    
    " Test that no project root is found with class method
    let project_root = indexer.get_project_root()
    call s:assert.equals(project_root, v:null)
    
    " Clean up
    call delete(temp_dir, 'rf')
endfunction

function! s:suite.test_get_index_file_creates_file_legacy()
    " Change to the test directory
    let original_dir = getcwd()
    execute 'cd ' . s:test_dir
    
    " Ensure index file doesn't exist yet
    call s:assert.false(filereadable(s:index_file))
    
    " Call legacy function that should create the file
    let index_file = s:normalize_path(vimqq#indexer#get_index_file())
    call s:assert.equals(index_file, s:normalize_path(s:index_file))
    
    " Verify file was created with empty dictionary
    call s:assert.true(filereadable(s:index_file))
    let content = readfile(s:index_file)
    call s:assert.equals(content[0], '{}')
    
    " Return to original directory
    execute 'cd ' . original_dir
endfunction

function! s:suite.test_get_index_file_creates_file_class()
    " Delete index file if it exists
    if filereadable(s:index_file)
        call delete(s:index_file)
    endif
    
    " Ensure index file doesn't exist yet
    call s:assert.false(filereadable(s:index_file))
    
    " Create an indexer instance with the test directory
    let indexer = vimqq#indexer#new(s:test_dir)
    
    " Call method that should create the file
    let index_file = s:normalize_path(indexer.get_index_file())
    call s:assert.equals(index_file, s:normalize_path(s:index_file))
    
    " Verify file was created with empty dictionary
    call s:assert.true(filereadable(s:index_file))
    let content = readfile(s:index_file)
    call s:assert.equals(content[0], '{}')
endfunction

function! s:suite.test_read_write_index_legacy()
    " Change to the test directory
    let original_dir = getcwd()
    execute 'cd ' . s:test_dir
    
    " Write test data to index with legacy function
    let test_data = {'test': 'data', 'number': 42}
    let result = vimqq#indexer#write_index(test_data)
    call s:assert.equals(result, 1)
    
    " Read data back with legacy function and verify
    let read_data = vimqq#indexer#read_index()
    call s:assert.equals(read_data.test, 'data')
    call s:assert.equals(read_data.number, 42)
    
    " Return to original directory
    execute 'cd ' . original_dir
endfunction

function! s:suite.test_read_write_index_class()
    " Create an indexer instance with the test directory
    let indexer = vimqq#indexer#new(s:test_dir)
    
    " Write test data to index with class method
    let test_data = {'test': 'data', 'number': 42}
    let result = indexer.write_index(test_data)
    call s:assert.equals(result, 1)
    
    " Read data back with class method and verify
    let read_data = indexer.read_index()
    call s:assert.equals(read_data.test, 'data')
    call s:assert.equals(read_data.number, 42)
    
    " Create a new indexer instance and verify it can read the same data
    let indexer2 = vimqq#indexer#new(s:test_dir)
    let read_data2 = indexer2.read_index()
    call s:assert.equals(read_data2.test, 'data')
    call s:assert.equals(read_data2.number, 42)
endfunction

function! s:suite.test_write_index_no_project_root_legacy()
    " Change to temp directory without .vqq
    let temp_dir = tempname()
    call mkdir(temp_dir, 'p')
    let original_dir = getcwd()
    execute 'cd ' . temp_dir
    
    " Try to write index with legacy function when no project root exists
    let test_data = {'test': 'data'}
    let result = vimqq#indexer#write_index(test_data)
    call s:assert.equals(result, 0)
    
    " Return to original directory and clean up
    execute 'cd ' . original_dir
    call delete(temp_dir, 'rf')
endfunction

function! s:suite.test_write_index_no_project_root_class()
    " Create a temp directory without .vqq
    let temp_dir = tempname()
    call mkdir(temp_dir, 'p')
    
    " Create an indexer instance with the temp directory
    let indexer = vimqq#indexer#new(temp_dir)
    
    " Try to write index with class method when no project root exists
    let test_data = {'test': 'data'}
    let result = indexer.write_index(test_data)
    call s:assert.equals(result, 0)
    
    " Clean up
    call delete(temp_dir, 'rf')
endfunction

function! s:suite.test_multiple_indexers()
    " Create a second test directory with .vqq
    let s:test_dir2 = s:normalize_path(tempname())
    let s:vqq_dir2 = s:test_dir2 . '/.vqq'
    let s:index_file2 = s:vqq_dir2 . '/index.json'
    call mkdir(s:test_dir2, 'p')
    call mkdir(s:vqq_dir2, 'p')
    
    " Create two indexer instances for different directories
    let indexer1 = vimqq#indexer#new(s:test_dir)
    let indexer2 = vimqq#indexer#new(s:test_dir2)
    
    " Write different test data to each index
    let test_data1 = {'test': 'data1', 'number': 1}
    let test_data2 = {'test': 'data2', 'number': 2}
    call indexer1.write_index(test_data1)
    call indexer2.write_index(test_data2)
    
    " Verify each indexer reads the correct data
    let read_data1 = indexer1.read_index()
    let read_data2 = indexer2.read_index()
    call s:assert.equals(read_data1.test, 'data1')
    call s:assert.equals(read_data1.number, 1)
    call s:assert.equals(read_data2.test, 'data2')
    call s:assert.equals(read_data2.number, 2)
    
    " Clean up second test directory
    call delete(s:test_dir2, 'rf')
endfunction
