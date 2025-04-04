if exists('g:autoloaded_vimqq_popup')
    finish
endif

let g:autoloaded_vimqq_popup = 1

let s:POPUP_TIMEOUT_MS = 5000

function! vimqq#platform#popup#show(lines)
  let lines = a:lines
  
  " Calculate dimensions
  let width = 0
  for line in lines
    let line_width = strdisplaywidth(line)
    if line_width > width
      let width = line_width
    endif
  endfor
  
  " Add some padding
  let width += 4
  let height = len(lines)
  
  " Calculate position (center of the screen)
  let pos_x = (winwidth(0) - width) / 2
  let pos_y = (winheight(0) - height) / 2
  
  " For Vim - create popup
  if exists('*popup_create')
    call popup_create(lines, {
          \ 'title': 'VimQQ status',
          \ 'pos': 'center',
          \ 'padding': [1, 2, 1, 2],
          \ 'border': [1, 1, 1, 1],
          \ 'borderchars': ['-', '|', '-', '|', '+', '+', '+', '+'],
          \ 'close': 'click',
          \ 'time': s:POPUP_TIMEOUT_MS,
          \ })
  " For Neovim - create floating window
  elseif has('nvim')
    let buf = nvim_create_buf(v:false, v:true)
    call nvim_buf_set_lines(buf, 0, -1, v:true, lines)
    
    let opts = {
          \ 'relative': 'editor',
          \ 'width': width,
          \ 'height': height,
          \ 'col': pos_x,
          \ 'row': pos_y,
          \ 'anchor': 'NW',
          \ 'style': 'minimal',
          \ 'border': 'rounded',
          \ }
    
    let win = nvim_open_win(buf, v:false, opts)
    
    " Auto-close after 5 seconds
    call timer_start(s:POPUP_TIMEOUT_MS, {-> nvim_win_close(win, v:true)})
  else
    " Fallback for older Vim versions
    echo "Status:"
    for line in lines
      echo line
    endfor
  endif
endfunction

