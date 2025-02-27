if exists('g:autoloaded_vimqq_lucas')
    finish
endif

let g:autoloaded_vimqq_lucas = 1

function! s:load_index_lines()
    let current_dir = expand('%:p:h')
    let prev_dir = ''

    while current_dir !=# prev_dir
      " Check if lucas.idx file exists in current dir
      let file_path = current_dir . '/lucas.idx'
      if filereadable(file_path)
          return readfile(file_path)
      endif

      let prev_dir = current_dir
      let current_dir = fnamemodify(current_dir, ':h')
    endwhile
    return v:null
endfunction

function! s:prepare_index_lines()
    let index_lines = s:load_index_lines()
    if index_lines is v:null
        return v:null
    endif

    let res = []
    let index = json_decode(join(index_lines, "\n"))
    for [filepath, data] in items(index.files)
        call add(res, filepath)
        call add(res, data.processing_result)
        call add(res, '')
    endfor
    for [filepath, data] in items(index.dirs)
        call add(res, filepath)
        call add(res, data.processing_result)
        call add(res, '')
    endfor

    return res
endfunction

function! vimqq#lucas#load()
    let index_lines = s:prepare_index_lines()
    if index_lines isnot v:null
        return join(index_lines, "\n")
    endif
    call vimqq#log#error('Unable to locate lucas.idx file')
    return v:null
endfunction

