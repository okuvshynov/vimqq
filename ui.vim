" default chat window width
let g:qq_width  = get(g:, 'qq_width', 80)

" User interface, buffer/window manipulation
let g:vqq#UI = {}

function! g:vqq#UI.new() dict
    let l:instance = copy(self)
    let l:instance._server_status = "unknown"
    return l:instance
endfunction

function! g:vqq#UI.update_statusline(status) dict
    if a:status != self._server_status
        let self._server_status = a:status
        redrawstatus!
    endif
endfunction

function! g:vqq#UI.open_window() dict
    " Check if the buffer already exists
    let l:bufnum = bufnr('vim_qna_chat')
    if l:bufnum == -1
        " Create a new buffer in a vertical split
        silent! execute 'topleft vertical ' . g:qq_width . ' new'
        silent! execute 'edit vim_qna_chat'
        setlocal buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
        function GetStatus() closure
            return self._server_status
        endfunction

        setlocal statusline=server\ status:\ %{GetStatus()}
    else
        let winnum = bufwinnr(l:bufnum)
        if winnum == -1
            silent! execute 'topleft vertical ' . g:qq_width . ' split'
            silent! execute 'buffer ' l:bufnum
        else
            silent! execute winnum . 'wincmd w'
        endif
    endif
    return l:bufnum
endfunction

function! g:vqq#UI.append_message(open_chat, message) dict
    if a:open_chat
        call self.open_window()
    endif

    let l:tstamp = "        "
    if has_key(a:message, 'timestamp')
        let l:tstamp = strftime(g:qq_timefmt . " ", a:message['timestamp'])
    endif
    if a:message['role'] == 'user'
        let prompt = l:tstamp . "  You: "
    else
        let prompt = l:tstamp . "Local: "
    endif
    let lines = split(a:message['content'], '\n')
    for l in lines
        if line('$') == 1 && getline(1) == ''
            call setline(1, prompt . l)
        else
            call append(line('$'), prompt . l)
        endif
        let prompt = ''
    endfor

    normal! G
endfunction

function! g:vqq#UI.append_partial(token) dict
    let l:bufnum    = bufnr('vim_qna_chat')
    let l:curr_line = getbufoneline(bufnum, '$')
    let l:lines     = split(l:curr_line . a:token . "\n", '\n')
    silent! call setbufline(l:bufnum, '$', l:lines)
endfunction

function! g:vqq#UI.display_prompt() dict
    "TODO: do that only if chat is open, not selection view
    let l:bufnum  = bufnr('vim_qna_chat')
    let l:msg     = strftime(g:qq_timefmt . " Local: ")
    let l:lines   = split(l:msg, '\n')
    call appendbufline(l:bufnum, line('$'), l:lines)
endfunction

function! g:vqq#UI.toggle() dict
    let bufnum = bufnr('vim_qna_chat')
    if bufnum == -1
        call self.open_window()
    else
        let l:winid = bufwinid('vim_qna_chat')
        if l:winid != -1
            call win_gotoid(l:winid)
            silent! execute 'hide'
        else
            call self.open_window()
        endif
    endif
endfunction

function! g:vqq#UI.get_visual_selection() dict
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end  , column_end  ] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0]  = lines[0][column_start - 1:]
    return join(lines, "\n")
endfunction

