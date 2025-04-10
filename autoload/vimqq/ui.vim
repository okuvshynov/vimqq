" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_ui_module')
    finish
endif

let g:autoloaded_vimqq_ui_module = 1

" -----------------------------------------------------------------------------
" configuration:
" default chat window width
let g:vqq_width = get(g:, 'vqq_width', 80)

" format to use in chat list
let g:vqq_time_format = get(g:, 'vqq_time_format', "%b %d %H:%M ")

let s:LIST_BUF_NAME = 'vimqq_chatlist'
let s:CHAT_BUF_NAME = 'vimqq_chat'

" buffer strict name match
function! s:bnrs(name)
    return bufnr('^' . a:name . '$')
endfunction

" -----------------------------------------------------------------------------
function vimqq#ui#new() abort
    let ui = {}

    let ui._bot_status = {}
    let ui._queue_size = 0

    " {{{ private:
    function! ui._open_list_window() dict
        " Check if the buffer already exists
        let bufnum = s:bnrs(s:LIST_BUF_NAME)
        if bufnum == -1
            " Create a new buffer in a vertical split
            silent! execute 'topleft vertical ' . (g:vqq_width) . ' new'
            silent! execute 'edit ' . s:LIST_BUF_NAME
            setlocal buftype=nofile
            setlocal bufhidden=hide
            setlocal noswapfile
            setlocal nomodifiable
            setlocal wfw 
        else
            let winnum = bufwinnr(bufnum)
            if winnum == -1
                silent! execute 'topleft vertical ' . (g:vqq_width) . ' split'
                silent! execute 'buffer ' bufnum
            else
                silent! execute winnum . 'wincmd w'
            endif
        endif
        return bufnum
    endfunction

    function! ui._open_chat_window() dict
        " Check if the buffer already exists
        let bufnum = s:bnrs(s:CHAT_BUF_NAME)
        if bufnum == -1
            " Create a new buffer in a vertical split
            silent! execute 'rightbelow vertical new'
            silent! execute 'edit ' . s:CHAT_BUF_NAME
            setlocal buftype=nofile
            setlocal bufhidden=hide
            setlocal noswapfile
            setlocal nomodifiable
            setlocal wfw 
            function GetStatus() closure
                let res = []
                for [name, status] in items(self._bot_status)
                    call add(res, name . ":" . status)
                endfor
                return join(res, ' | ')
            endfunction

            function GetQueueSize() closure
                return "queue: " . self._queue_size
            endfunction

            setlocal statusline=%{GetStatus()}%=%{GetQueueSize()}
        else
            let winnum = bufwinnr(bufnum)
            if winnum == -1
                silent! execute 'vert sb ' bufnum
            else
                silent! execute winnum . 'wincmd w'
            endif
        endif
        return bufnum
    endfunction

    function! ui._append_message(message) dict
        setlocal modifiable
        for l in vimqq#msg_render#render_lines(a:message)
            if line('$') == 1 && getline(1) ==# ''
                call setline(1, l)
            else
                call append(line('$'), l)
            endif
        endfor
        setlocal nomodifiable

        normal! G
    endfunction

    " }}}

    " {{{ public:

    function! ui.append_partial(chunk) dict
        let bufnum = s:bnrs(s:CHAT_BUF_NAME)
        if bufnum != -1
            let curr_line = getbufline(bufnum, '$')[0]
            let lines     = split(curr_line . a:chunk . "\n", '\n')
            silent! call setbufvar(bufnum, '&modifiable', 1)
            silent! call setbufline(bufnum, '$', lines)
            silent! call setbufvar(bufnum, '&modifiable', 0)
        endif
    endfunction

    function! ui.display_chat_history(history, current_chat) dict
        let titles = []
        let chat_id_map = {}

        for item in a:history
            let sep = ' '
            if a:current_chat ==# item.id
                let selected_line = len(titles) + 1
                let sep = '>'
            endif

            call add(titles, strftime(g:vqq_time_format . sep . item.title, item.time))
            let chat_id_map[len(titles)] = item.id
        endfor

        call self._open_list_window()

        setlocal modifiable
        silent! call deletebufline('%', 1, '$')
        call setline(1, titles)
        if exists('selected_line')
            call cursor(selected_line, 1)
        endif
        setlocal cursorline
        setlocal nomodifiable
        
        mapclear <buffer>

        function! ShowChat() closure
            let chat_id = chat_id_map[line('.')]
            call vimqq#main#notify('chat_selected', {'chat_id': chat_id})
        endfunction

        function! HideList() closure
            call self.hide_list()
        endfunction

        function! DeleteChat() closure
            let chat_id = chat_id_map[line('.')]
            call timer_start(0, { -> vimqq#main#notify('delete_chat', {'chat_id': chat_id}) })
        endfunction

        nnoremap <silent> <buffer> <cr> :call ShowChat()<cr>
        nnoremap <silent> <buffer> q    :call HideList()<cr>
        nnoremap <silent> <buffer> d    :call DeleteChat()<cr>
    endfunction

    function ui.display_chat(messages, partial) dict
        call self._open_chat_window()

        mapclear <buffer>
        setlocal modifiable
        setlocal cursorline<
        setlocal foldmethod=marker
        setlocal foldmarker={{{,}}}
        silent! call deletebufline('%', 1, '$')

        for message in a:messages
            call self._append_message(message)
        endfor

        " display streamed partial response
        if a:partial isnot v:null
            if has_key(a:partial, 'bot_name') && !empty(a:partial.bot_name)
                call self._append_message(a:partial)
            endif
        endif
    endfunction

    function! ui.hide_list() dict
        let list_bufnum = s:bnrs(s:LIST_BUF_NAME)
        let list_winid = bufwinid(s:LIST_BUF_NAME)
        if list_winid != -1
            call win_gotoid(list_winid)
            silent! execute 'hide'
        endif
    endfunction

    " }}}

    return ui
endfunction

" -----------------------------------------------------------------------------
" basic color scheme setup
function! s:setup_syntax()
    syntax clear

    syntax match timestr    "^\d\d:\d\d"      nextgroup=userPrompt,botPrompt,infoPrompt,warnPrompt,errorPrompt skipwhite

    syntax match userPrompt  "You:"     contained nextgroup=taggedBot       skipwhite
    syntax match infoPrompt  "info:"    contained nextgroup=restOfLineInfo  skipwhite
    syntax match warnPrompt  "warning:" contained nextgroup=restOfLineWarn  skipwhite
    syntax match errorPrompt "error:"   contained nextgroup=restOfLineError skipwhite
    syntax match botPrompt  "\%(You\|info\|warning\|error\)\@![A-Za-z0-9_]\+:" contained nextgroup=restOfLine skipwhite
    syntax match taggedBot  "@[A-Za-z0-9_]\+" contained nextgroup=restOfLine
    syntax match indexSize  "\[index (\d\+ bytes)\]"
    syntax match toolCallRes "\[tool_call_result\]"

    syntax match functionCall "^>>>" nextgroup=restOfLineFn skipwhite

    syntax match restOfLine      ".*$" contained
    syntax match restOfLineFn    ".*$" contained
    syntax match restOfLineInfo  ".*$" contained
    syntax match restOfLineWarn  ".*$" contained
    syntax match restOfLineError ".*$" contained

    highlight link userPrompt Identifier
    highlight link botPrompt Identifier

    highlight link infoPrompt     Title
    highlight link restOfLineInfo Title

    highlight link warnPrompt     WarningMsg
    highlight link restOfLineWarn WarningMsg

    highlight link errorPrompt     ErrorMsg
    highlight link restOfLineError ErrorMsg

    highlight link timestr Constant
    highlight link taggedBot Comment
    highlight link indexSize Todo

    highlight link toolCallRes Todo

    highlight link functionCall Constant
    "highlight link restOfLineFn Todo
endfunction

augroup VQQSyntax
  autocmd!
  execute 'autocmd BufRead,BufNewFile *' . s:CHAT_BUF_NAME . ' call s:setup_syntax()'
augroup END
