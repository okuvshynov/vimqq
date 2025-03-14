" Copyright 2025 Oleksandr Kuvshynov
" This file is maintained for backwards compatibility.
" All functionality has been moved to the vimqq/indexing/ directory.

if exists('g:autoloaded_vimqq_indexer')
    finish
endif

let g:autoloaded_vimqq_indexer = 1

" Creates a new indexer instance for the specified starting directory
function! vimqq#indexer#new(...)
    return call('vimqq#indexing#new', a:000)
endfunction

" Public function to get the project root directory
function! vimqq#indexer#get_project_root()
    return vimqq#indexing#get_project_root()
endfunction

" Public function to get the path to the index file
function! vimqq#indexer#get_index_file()
    return vimqq#indexing#get_index_file()
endfunction

" Reads the index file and returns its contents as a dictionary
function! vimqq#indexer#read_index()
    return vimqq#indexing#read_index()
endfunction

" Writes a dictionary to the index file
function! vimqq#indexer#write_index(index_data)
    return vimqq#indexing#write_index(a:index_data)
endfunction

" Gets list of all files in the project using git ls-files
function! vimqq#indexer#get_git_files(...)
    return call('vimqq#indexing#get_git_files', a:000)
endfunction

" Process up to N files from the queue, counting tokens for each file's content
function! vimqq#indexer#process_token_counts(max_files, ...)
    return call('vimqq#indexing#process_token_counts', [a:max_files] + a:000)
endfunction
