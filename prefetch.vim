"
" This is a template to allow preprocessing of the context while user is
" typing a question. For now not connected with main functionality

function! s:start_prefetch()
    let s:visual_selection = s:get_visual_selection()
    call timer_start(0, function('s:preprocess'))
    call feedkeys(":'<,'>QQ ", 'n')
endfunction

function! s:get_visual_selection()
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]
    return join(lines, "\n")
endfunction

function! s:call_prefetch(lines)
  return a:lines
endfunction

function! s:preprocess(timer)
    let s:preprocessed_data = s:call_prefetch(s:visual_selection)
endfunction

function! s:call_api(cmd)
    " Use the preprocessed data here
    if exists('s:preprocessed_data')
        echo "Preprocessing done, now passing " . a:cmd .  " as well"
        "call s:main_call(s:preprocessed_data, a:cmd)
    else
        echo "Preprocessing not complete"
    endif
endfunction

xnoremap <silent> QQ :<C-u>call <SID>start_prefetch()<CR>

" Define your custom command
command! -range -nargs=+ QQ call s:call_api(<q-args>)
