" Copyright 2024 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_full_context')
    finish
endif
let g:autoloaded_vimqq_full_context = 1

let s:filetypes = "*.vim,*.txt,*.md,*.cpp,*.c,*.h,*.hpp,*.py,*.rs"
let g:vqq_context_filetypes = get(g:, 'vqq_context_filetypes', s:filetypes)

" recursively build a list of [[file_path/name, content]]
" for all files matching pattern (e.g. "*.cpp,*.c,*.h")
" within start_dir recursively.
function! s:list_files(start_dir, pattern)
    let l:result = []
    let l:patterns = split(a:pattern, ',')
    
    for l:pattern in l:patterns
        let l:files = globpath(a:start_dir, '**/' . l:pattern, 0, 1)
        for l:file in l:files
            if filereadable(l:file)
                let l:content = readfile(l:file)
                call add(l:result, [l:file, l:content])
            endif
        endfor
    endfor
    
    return l:result
endfunction

function! s:combine_files(file_list)
    let l:result = []
    
    for [file, content] in a:file_list
        " Add file name header
        call add(l:result, "///// FILE: " . file . " /////")
        
        " Add file content
        call extend(l:result, content)
        
        " Add an extra empty line
        call add(l:result, "")
    endfor
    
    " Remove the last empty line
    if len(l:result) > 0
        call remove(l:result, -1)
    endif
    
    return l:result
endfunction

function! s:find_root()
  " Get the directory of the current file
  let l:current_dir = expand('%:p:h')
  let l:prev_dir = ''

  while l:current_dir != l:prev_dir
      " Check if .git directory exists
      if isdirectory(l:current_dir . '/.git')
          return l:current_dir
      endif

      let l:prev_dir = l:current_dir
      let l:current_dir = fnamemodify(l:current_dir, ':h')
  endwhile

  " If we reach here, we didn't find a .git directory
  echom "No .git directory found. Stopped at filesystem root."
  return l:current_dir
endfunction

function! vimqq#full_context#get(pattern=g:vqq_context_filetypes)
    let l:root  = s:find_root()
    let l:files = s:list_files(l:root, a:pattern) 
    return join(s:combine_files(l:files), "\n")
endfunction
