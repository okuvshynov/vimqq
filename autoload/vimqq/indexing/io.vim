if exists('g:autoloaded_vimqq_indexing_io')
    finish
endif

let g:autoloaded_vimqq_indexing_io = 1

let s:INDEX_DIRECTORY = '.vqq'
let s:IGNORE_FILE     = '.vqqignore'

function! vimqq#indexing#io#root()
    let current_dir = expand('%:p:h')
    let prev_dir = ''

    while current_dir !=# prev_dir
        let dir_path = current_dir . '/' . s:INDEX_DIRECTORY
        if isdirectory(dir_path)
            return current_dir
        endif

        let prev_dir = current_dir
        let current_dir = fnamemodify(current_dir, ':h')
    endwhile
    return v:null
endfunction

function! vimqq#indexing#io#ignores()
    let root = vimqq#indexing#io#root()
    let res = []
    if root isnot v:null
        let file_path = root . '/' . s:IGNORE_FILE
        if filereadable(file_path)
            let res = readfile(file_path)
        endif
    endif
    call add(res, s:INDEX_DIRECTORY . '/*')
    return res
endfunction

function! vimqq#indexing#io#read(index_name)
    let root = vimqq#indexing#io#root()
    if root is v:null
        call vimqq#log#error('attempt to read index with no index dir.')
        return v:null
    endif
    let file_path = root . '/' . s:INDEX_DIRECTORY . '/' . a:index_name
    if filereadable(file_path)
        return json_decode(join(readfile(file_path)))
    endif
    return {}
endfunction

function! vimqq#indexing#io#write(index_name, data)
    let root = vimqq#indexing#io#root()
    if root is v:null
        call vimqq#log#error('attempt to write index with no index dir.')
        return
    endif
    let dir_path  = root . '/' . s:INDEX_DIRECTORY
    call mkdir(dir_path, 'p')
    let file_path = dir_path . '/' . a:index_name
    let json_text = json_encode(a:data)
    call writefile([json_text], file_path)
endfunction
