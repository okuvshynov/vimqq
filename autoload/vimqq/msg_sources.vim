if exists('g:autoloaded_vimqq_ctx')
    finish
endif

let g:autoloaded_vimqq_ctx = 1

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

" Fill sources (index, selection) into message object
function! vimqq#msg_sources#fill(message, context, use_index)
    let message = deepcopy(a:message)

    if a:context isnot v:null
        let message.sources.context = a:context
    endif
    if a:use_index
        let index_lines = s:load_index_lines()
        if index_lines isnot v:null
            let message.sources.index = join(index_lines, '\n')
        else
            call vimqq#log#error('Unable to locate lucas.idx file')
        endif
    endif
    return message
endfunction

