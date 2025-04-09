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
        return {}
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

function! s:collect_rec(base_dir, current_dir, result)
    for item in glob(a:current_dir . '/*', 0, 1)
        if isdirectory(item)
            call s:collect_rec(a:base_dir, item, a:result)
        elseif filereadable(item)
            let file_content = join(readfile(item), "\n")
            try
                let json_data = json_decode(file_content)
                if type(json_data) == v:t_dict && has_key(json_data, 'summary')
                    let relative_path = substitute(item, a:base_dir . '/', '', '')
                    let a:result[relative_path] = json_data.summary
                endif
            catch
                call vimqq#log#error('skipping ' . string(item))
                continue
            endtry
        endif
    endfor
endfunction

function! vimqq#indexing#io#collect(index_name)
    let root = vimqq#indexing#io#root()
    if root is v:null
        call vimqq#log#error('attempt to read index with no index dir.')
        return
    endif
    let result = {}

    let base_dir = root . '/' . s:INDEX_DIRECTORY . '/' . a:index_name
    if isdirectory(base_dir)
        call s:collect_rec(base_dir, base_dir, result)
    endif

    return result
endfunction

function! vimqq#indexing#io#rm(index_name, path)
    let root = vimqq#indexing#io#root()
    if root is v:null
        call vimqq#log#error('attempt to read index with no index dir.')
        return
    endif
    let path = root . '/' . s:INDEX_DIRECTORY . '/' . a:path
    let path = fnameescape(path)

    if filereadable(path)
        call delete(path)
    endif
endfunction

" For now let's keep tag -> file only
function! vimqq#indexing#io#ctags()
    let root = vimqq#indexing#io#root()
    let tags_path = root . '/tags'
    let res = []
    if filereadable(tags_path)
         for tagline in readfile(tags_path)
             let parts = split(tagline, '\t')
             if len(parts) >= 2
                call add(res, [parts[0], parts[1]])
             endif
         endfor
    endif
    return join(res, '\n')
endfunction

function! vimqq#indexing#io#read_path(index_name, file_path)
    let root = vimqq#indexing#io#root()
    if root is v:null
        call vimqq#log#error('attempt to read index with no index dir.')
        return v:null
    endif
    let index_path = root . '/' . s:INDEX_DIRECTORY . '/' . a:index_name
    let full_path = index_path . '/' . a:file_path
    if filereadable(full_path)
        return json_decode(join(readfile(full_path)))
    endif
    return {}
endfunction

function! vimqq#indexing#io#write_path(index_name, file_path, data)
    let root = vimqq#indexing#io#root()
    if root is v:null
        call vimqq#log#error('attempt to write index with no index dir.')
        return
    endif
    let index_path = root . '/' . s:INDEX_DIRECTORY . '/' . a:index_name
    let full_path = index_path . '/' . a:file_path
    let dir_path = fnamemodify(full_path, ':h')
    try
        call mkdir(dir_path, 'p')
    catch
        call vimqq#log#error('failed to create dir: ' . dir_path)
        return
    endtry
    let json_text = json_encode(a:data)
    call writefile([json_text], full_path)
endfunction
