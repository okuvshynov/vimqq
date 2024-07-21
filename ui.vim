" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
" configuration:
" default chat window width
let g:vqq_width = get(g:, 'vqq_width', 80)

" format to use in chat list
let g:vqq_time_format = get(g:, 'vqq_time_format', "%Y-%m-%d %H:%M:%S ")

" format to use for each message. Not configurable, we have hardcoded syntax
let s:time_format = "%H:%M:%S"

" -----------------------------------------------------------------------------
" User interface, buffer/window manipulation
let g:vqq#UI = {}

source vqq_module.vim

function! g:vqq#UI.new() dict
    " poor man inheritance 
    let l:instance = g:vqq#Base.new()
    call extend(l:instance, copy(self))

    let l:instance._server_status = "unknown"
    let l:instance._bot_status = {}
    return l:instance
endfunction

" {{{ private:

function! g:vqq#UI._open_window() dict
    " Check if the buffer already exists
    let l:bufnum = bufnr('vim_qna_chat')
    if l:bufnum == -1
        " Create a new buffer in a vertical split
        silent! execute 'topleft vertical ' . g:vqq_width . ' new'
        silent! execute 'edit vim_qna_chat'
        setlocal buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
        function GetStatus() closure
            let res = []
            for [name, status] in items(self._bot_status)
                call add(res, name . ":" . status)
            endfor
            return join(res, ' | ')
        endfunction

        setlocal statusline=status:\ %{GetStatus()}
    else
        let winnum = bufwinnr(l:bufnum)
        if winnum == -1
            silent! execute 'topleft vertical ' . g:vqq_width . ' split'
            silent! execute 'buffer ' l:bufnum
        else
            silent! execute winnum . 'wincmd w'
        endif
    endif
    return l:bufnum
endfunction

function! g:vqq#UI._append_message(open_chat, message) dict
    if a:open_chat
        call self._open_window()
    endif

    let l:tstamp = "        "
    if has_key(a:message, 'timestamp')
        let l:tstamp = strftime(s:time_format . " ", a:message['timestamp'])
    endif
    if a:message['role'] == 'user'
        let prompt = l:tstamp . "You: @" . a:message['bot_name'] . " " 
    else
        let prompt = l:tstamp . a:message['bot_name'] . ": "
    endif
    let lines = split(prompt . a:message['content'], '\n')
    for l in lines
        if line('$') == 1 && getline(1) == ''
            call setline(1, l)
        else
            call append(line('$'), l)
        endif
    endfor

    normal! G
endfunction

" }}}
" {{{ public:

function! g:vqq#UI.update_statusline(status, bot_name) dict
    if !has_key(self._bot_status, a:bot_name) || self._bot_status[a:bot_name] != a:status
        let self._bot_status[a:bot_name] = a:status
        redrawstatus!
    endif
endfunction

function! g:vqq#UI.append_partial(token) dict
    let l:bufnum    = bufnr('vim_qna_chat')
    let l:curr_line = getbufoneline(bufnum, '$')
    let l:lines     = split(l:curr_line . a:token . "\n", '\n')
    silent! call setbufline(l:bufnum, '$', l:lines)
endfunction

function! g:vqq#UI.display_chat_history(history, current_chat) dict
    let l:titles = []
    let l:chat_id_map = {}

    for item in a:history
        let l:sep = ' '
        if a:current_chat == item.id
            let l:selected_line = len(titles) + 1
            let l:sep = '>'
        endif

        call add(l:titles, strftime(g:vqq_time_format . l:sep . item.title, item.time))
        let l:chat_id_map[len(titles)] = item.id
    endfor

    call self._open_window()

    setlocal modifiable
    silent! call deletebufline('%', 1, '$')
    call setline(1, l:titles)
    if exists('l:selected_line')
        call cursor(l:selected_line, 1)
    endif
    " TODO - turn it off when viewing the individual chat
    setlocal cursorline
    setlocal nomodifiable
    
    mapclear <buffer>

    function! ShowChat() closure
        call self.call_cb('chat_select_cb', l:chat_id_map[line('.')])
    endfunction

    function! Toggle() closure
        call self.toggle()
    endfunction
    nnoremap <silent> <buffer> <CR> :call ShowChat()<CR>
    nnoremap <silent> <buffer> q    :call Toggle()<CR>
endfunction

function g:vqq#UI.display_chat(messages, partial) dict
    call self._open_window()

    mapclear <buffer>
    setlocal modifiable
    silent! call deletebufline('%', 1, '$')

    for l:message in a:messages
        call self._append_message(v:false, l:message)
    endfor

    " display streamed partial response
    if has_key(a:partial, 'bot_name') && !empty(a:partial.bot_name)
        call self._append_message(v:false, a:partial)
    endif

    function! ShowChatList() closure
        call self.call_cb('chat_list_cb')
    endfunction

    nnoremap <silent> <buffer> q  :call ShowChatList()<CR>
endfunction

function! g:vqq#UI.toggle() dict
    let bufnum = bufnr('vim_qna_chat')
    if bufnum == -1
        call self._open_window()
    else
        let l:winid = bufwinid('vim_qna_chat')
        if l:winid != -1
            call win_gotoid(l:winid)
            silent! execute 'hide'
        else
            call self._open_window()
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

" }}}

" -----------------------------------------------------------------------------
" basic color scheme setup
function! s:setup_syntax()
    syntax clear

    syntax match prompt     "^\d\d:\d\d:\d\d\s*[A-Za-z0-9_]\+:" nextgroup=taggedBot skipwhite
    syntax match taggedBot  "@[A-Za-z0-9_]\+"                   nextgroup=restOfLine

    syntax match restOfLine ".*$" contained

    highlight prompt     cterm=reverse gui=reverse
    highlight taggedBot  ctermfg=DarkBlue guifg=DarkBlue
endfunction

augroup VQQSyntax
  autocmd!
  autocmd BufRead,BufNewFile *vim_qna_chat* call s:setup_syntax()
augroup END
