" Copyright 2025 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_indexing')
    finish
endif

let g:autoloaded_vimqq_indexing = 1

" Creates a new indexer instance for the specified starting directory
" If no directory is provided, the current working directory is used
function! vimqq#indexing#new(...)
    return call('vimqq#indexing#core#new', a:000)
endfunction

" For backwards compatibility: these functions use a default indexer instance
" Public function to get the project root directory
function! vimqq#indexing#get_project_root()
    let indexer = vimqq#indexing#new()
    return indexer.get_project_root()
endfunction

" Public function to get the path to the index file
function! vimqq#indexing#get_index_file()
    let indexer = vimqq#indexing#new()
    return indexer.get_index_file()
endfunction

" Reads the index file and returns its contents as a dictionary
function! vimqq#indexing#read_index()
    let indexer = vimqq#indexing#new()
    return indexer.read_index()
endfunction

" Writes a dictionary to the index file
function! vimqq#indexing#write_index(index_data)
    let indexer = vimqq#indexing#new()
    return indexer.write_index(a:index_data)
endfunction

" Gets list of all files in the project using git ls-files
" Optional callback function can be provided to process files after indexing
function! vimqq#indexing#get_git_files(...)
    let indexer = vimqq#indexing#new()
    return call(indexer.get_git_files, a:000, indexer)
endfunction

" Process up to N files from the queue, counting tokens for each file's content
" and writing the results to the JSON index
" Optional callback function can be provided to handle the completion event
function! vimqq#indexing#process_token_counts(max_files, ...)
    let indexer = vimqq#indexing#new()
    return call(indexer.process_token_counts, [a:max_files] + a:000, indexer)
endfunction