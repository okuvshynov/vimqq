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

" format to use for each message. Not configurable, we have hardcoded syntax
let s:time_format = "%H:%M"

let s:showing = 'list'

" -----------------------------------------------------------------------------
function vimqq#ui#new() abort
    let l:ui = {}

    call extend(l:ui, vimqq#base#new())

    let l:ui._bot_status = {}
    let l:ui._queue_size = 0

    " {{{ private:
    function! l:ui._open_window() dict
        " Check if the buffer already exists
        let l:bufnum = bufnr('vim_qna_chat')
        if l:bufnum == -1
            " Create a new buffer in a vertical split
            silent! execute 'topleft vertical ' . g:vqq_width . ' new'
            silent! execute 'edit vim_qna_chat'
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

    function! l:ui._append_message(open_chat, message) dict
        if a:open_chat
            call self._open_window()
        endif

        setlocal modifiable
        let l:tstamp = "        "
        if has_key(a:message, 'timestamp')
            let l:tstamp = strftime(s:time_format . " ", a:message['timestamp'])
        endif
        if a:message['role'] == 'user'
            let prompt = l:tstamp . "You: @" . a:message['bot_name'] . " " 
        else
            let prompt = l:tstamp . a:message['bot_name'] . ": "
        endif
        let l:content = a:message
        let lines = split(prompt . a:message['content'], '\n')
        for l in lines
            if line('$') == 1 && getline(1) == ''
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

    function! l:ui.update_statusline(status, bot_name) dict
        if !has_key(self._bot_status, a:bot_name) || self._bot_status[a:bot_name] != a:status
            let self._bot_status[a:bot_name] = a:status
            redrawstatus!
        endif
    endfunction

    function! l:ui.update_queue_size(queue_size) dict
        if self._queue_size != a:queue_size
            let self._queue_size = a:queue_size
            redrawstatus!
        endif
    endfunction

    function! l:ui.append_partial(token) dict
        if s:showing == 'chat'
            let l:bufnum    = bufnr('vim_qna_chat')
            let l:curr_line = getbufline(bufnum, '$')[0]
            let l:lines     = split(l:curr_line . a:token . "\n", '\n')
            silent! call setbufvar(l:bufnum, '&modifiable', 1)
            silent! call setbufline(l:bufnum, '$', l:lines)
            silent! call setbufvar(l:bufnum, '&modifiable', 0)
        endif
    endfunction

    function! l:ui.display_chat_history(history, current_chat) dict
        let s:showing = 'list'
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
        setlocal cursorline
        setlocal nomodifiable
        
        mapclear <buffer>

        function! ShowChat() closure
            call self.call_cb('chat_select_cb', l:chat_id_map[line('.')])
        endfunction

        function! Toggle() closure
            call self.toggle()
        endfunction

        " this one is interesting and I'm probably doing it wrong
        " if as a result of deletion you need to render chat history again,
        " we'll be redefining this closure while running within its context,
        " so that stack would look like DeleteChat -> some_cb -> mode_ops ->
        " display_chat_history. We cannot redefine it while it is running, so
        " let's use timer to break the chain.
        "
        " TODO: should we do the same for all callbacks and move this to base
        " module?
        function! DeleteChat() closure
            call timer_start(0, { -> self.call_cb('chat_delete_cb', l:chat_id_map[line('.')])})
        endfunction

        nnoremap <silent> <buffer> <cr> :call ShowChat()<cr>
        nnoremap <silent> <buffer> q    :call Toggle()<cr>
        nnoremap <silent> <buffer> d    :call DeleteChat()<cr>
    endfunction

    function l:ui.display_chat(messages, partial) dict
        let s:showing = 'chat'
        call self._open_window()

        mapclear <buffer>
        setlocal modifiable
        setlocal cursorline<
        setlocal foldmethod=marker
        setlocal foldmarker={{{,}}}
        silent! call deletebufline('%', 1, '$')

        for l:message in a:messages
            call self._append_message(v:false, vimqq#fmt#one(l:message, v:true))
        endfor

        " display streamed partial response
        if has_key(a:partial, 'bot_name') && !empty(a:partial.bot_name)
            call self._append_message(v:false, a:partial)
        endif

        function! ShowChatList() closure
            call self.call_cb('chat_list_cb')
        endfunction

        nnoremap <silent> <buffer> q  :call ShowChatList()<cr>
    endfunction

    function! l:ui.toggle() dict
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

    " }}}

    return l:ui
endfunction

" -----------------------------------------------------------------------------
" basic color scheme setup
function! s:setup_syntax()
    syntax clear

    syntax match timestr    "^\d\d:\d\d"      nextgroup=userPrompt,botPrompt skipwhite
    syntax match userPrompt "You:"            contained nextgroup=taggedBot skipwhite
    syntax match botPrompt  "\%(You\)\@![A-Za-z0-9_]\+:" contained nextgroup=restOfLine skipwhite
    syntax match taggedBot  "@[A-Za-z0-9_]\+" contained nextgroup=restOfLine

    syntax match restOfLine ".*$" contained

    highlight timestr    cterm=bold gui=bold
    highlight botPrompt  cterm=bold gui=bold ctermfg=DarkBlue guifg=DarkBlue
    highlight userPrompt cterm=bold gui=bold ctermfg=DarkRed guifg=DarkRed
    highlight taggedBot  ctermfg=DarkBlue guifg=DarkBlue
endfunction

augroup VQQSyntax
  autocmd!
  autocmd BufRead,BufNewFile *vim_qna_chat* call s:setup_syntax()
augroup END
