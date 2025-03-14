let s:suite = themis#suite('test_indexing_module')
let s:assert = themis#helper('assert')

" Load the new module to ensure it's available for testing
runtime autoload/vimqq/indexing.vim
runtime autoload/vimqq/indexing/core.vim
runtime autoload/vimqq/indexing/file.vim
runtime autoload/vimqq/indexing/git.vim
runtime autoload/vimqq/indexing/token.vim

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

function! s:suite.test_indexing_modules_loaded()
    " Test that the new modules are correctly loaded
    call s:assert.true(exists('*vimqq#indexing#new'), 'vimqq#indexing#new should exist')
    call s:assert.true(exists('*vimqq#indexing#core#new'), 'vimqq#indexing#core#new should exist')
    call s:assert.true(exists('*vimqq#indexing#file#ensure_index_file'), 'vimqq#indexing#file#ensure_index_file should exist')
    call s:assert.true(exists('*vimqq#indexing#git#get_files'), 'vimqq#indexing#git#get_files should exist')
    call s:assert.true(exists('*vimqq#indexing#token#process_counts'), 'vimqq#indexing#token#process_counts should exist')
endfunction

function! s:suite.test_indexing_core_find_project_root()
    " Test the new core module's find_project_root function
    let project_root = vimqq#indexing#core#find_project_root(s:test_dir)
    call s:assert.equals(s:normalize_path(project_root), s:normalize_path(s:vqq_dir))
endfunction

function! s:suite.test_indexing_file_ensure_index_file()
    " Test the new file module's ensure_index_file function
    let index_file = vimqq#indexing#file#ensure_index_file(s:vqq_dir)
    call s:assert.equals(s:normalize_path(index_file), s:normalize_path(s:index_file))
    call s:assert.true(filereadable(s:index_file))
endfunction

function! s:suite.test_indexing_file_read_write()
    " Test the new file module's read and write functions
    let test_data = {'test': 'data', 'number': 42}
    
    " Write data to the index file
    let index_file = vimqq#indexing#file#ensure_index_file(s:vqq_dir)
    call vimqq#indexing#file#write_index(index_file, test_data)
    
    " Read the data back
    let read_data = vimqq#indexing#file#read_index(index_file)
    
    " Verify data matches
    call s:assert.equals(read_data.test, 'data')
    call s:assert.equals(read_data.number, 42)
endfunction

function! s:suite.test_direct_module_vs_compatibility_layer()
    " Test that both approaches yield the same result
    
    " Create an indexer using the new direct module
    let indexer_new = vimqq#indexing#new(s:test_dir)
    let project_root_new = indexer_new.get_project_root()
    
    " Create an indexer using the compatibility layer
    let indexer_compat = vimqq#indexer#new(s:test_dir)
    let project_root_compat = indexer_compat.get_project_root()
    
    " Both should return the same project root
    call s:assert.equals(
        \ s:normalize_path(project_root_new), 
        \ s:normalize_path(project_root_compat)
    \ )
    
    " Test static functions too
    call s:assert.equals(
        \ s:normalize_path(vimqq#indexing#get_project_root()), 
        \ s:normalize_path(vimqq#indexer#get_project_root())
    \ )
endfunction
