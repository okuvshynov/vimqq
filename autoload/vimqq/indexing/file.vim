" Copyright 2025 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_indexing_file')
    finish
endif

let g:autoloaded_vimqq_indexing_file = 1

" Checks for index.json in the .vqq directory
" Creates it with an empty dictionary if it doesn't exist
" Returns the path to index.json
function! vimqq#indexing#file#ensure_index_file(project_root)
    let index_file = a:project_root . '/index.json'
    
    if !filereadable(index_file)
        " Create an empty dictionary as JSON
        let empty_dict = json_encode({})
        call writefile([empty_dict], index_file)
        call vimqq#log#info('Created empty index.json file at ' . index_file)
    endif
    
    " Resolve any symlinks in the path
    return resolve(index_file)
endfunction

" Read the index file and return its contents as a dictionary
" Returns an empty dictionary if the file cannot be read
function! vimqq#indexing#file#read_index(index_file)
    if filereadable(a:index_file)
        let lines = readfile(a:index_file)
        return json_decode(join(lines, "\n"))
    endif
    
    return {}
endfunction

" Write a dictionary to the index file
" Returns 1 on success, 0 on failure
function! vimqq#indexing#file#write_index(index_file, index_data)
    let json_data = json_encode(a:index_data)
    call writefile([json_data], a:index_file)
    return 1
endfunction