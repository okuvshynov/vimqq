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

function! s:suite.test_find_project_root()
    " Change to the test directory
    let original_dir = getcwd()
    execute 'cd ' . s:test_dir
    
    " Test finding project root
    let project_root = s:normalize_path(vimqq#indexer#get_project_root())
    call s:assert.equals(project_root, s:normalize_path(s:vqq_dir))
    
    " Return to original directory
    execute 'cd ' . original_dir
endfunction

function! s:suite.test_no_project_root()
    " Change to temp directory without .vqq
    let temp_dir = tempname()
    call mkdir(temp_dir, 'p')
    let original_dir = getcwd()
    execute 'cd ' . temp_dir
    
    " Test that no project root is found
    let project_root = vimqq#indexer#get_project_root()
    call s:assert.equals(project_root, v:null)
    
    " Return to original directory and clean up
    execute 'cd ' . original_dir
    call delete(temp_dir, 'rf')
endfunction

function! s:suite.test_get_index_file_creates_file()
    " Change to the test directory
    let original_dir = getcwd()
    execute 'cd ' . s:test_dir
    
    " Ensure index file doesn't exist yet
    call s:assert.false(filereadable(s:index_file))
    
    " Call function that should create the file
    let index_file = s:normalize_path(vimqq#indexer#get_index_file())
    call s:assert.equals(index_file, s:normalize_path(s:index_file))
    
    " Verify file was created with empty dictionary
    call s:assert.true(filereadable(s:index_file))
    let content = readfile(s:index_file)
    call s:assert.equals(content[0], '{}')
    
    " Return to original directory
    execute 'cd ' . original_dir
endfunction

function! s:suite.test_read_write_index()
    " Change to the test directory
    let original_dir = getcwd()
    execute 'cd ' . s:test_dir
    
    " Write test data to index
    let test_data = {'test': 'data', 'number': 42}
    let result = vimqq#indexer#write_index(test_data)
    call s:assert.equals(result, 1)
    
    " Read data back and verify
    let read_data = vimqq#indexer#read_index()
    call s:assert.equals(read_data.test, 'data')
    call s:assert.equals(read_data.number, 42)
    
    " Return to original directory
    execute 'cd ' . original_dir
endfunction

function! s:suite.test_write_index_no_project_root()
    " Change to temp directory without .vqq
    let temp_dir = tempname()
    call mkdir(temp_dir, 'p')
    let original_dir = getcwd()
    execute 'cd ' . temp_dir
    
    " Try to write index when no project root exists
    let test_data = {'test': 'data'}
    let result = vimqq#indexer#write_index(test_data)
    call s:assert.equals(result, 0)
    
    " Return to original directory and clean up
    execute 'cd ' . original_dir
    call delete(temp_dir, 'rf')
endfunction
