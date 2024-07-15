" Copyright 2024 Oleksandr Kuvshynov

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" configuration one can do in vimrc
" shared config
let g:vqna_max_tokens = get(g:, 'vqna_max_tokens', 1024)

" local llama_duo server config
let g:vqna_llama_duo  = get(g:, 'vqna_llama_duo' , "http://localhost:5555/query")
let g:qq_width        = get(g:, 'qq_width'       , 80)

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" should this be configurable?
" should each session have its own file?
let s:history_file   = expand('~/.vim/qq_history')
" cleanup dead jobs if list is longer than this
let s:n_jobs_cleanup = 32

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" local state. This should be by session?
let s:active_jobs = []

let s:current_reply = ""
let s:history = []

function! s:load_history()
    if filereadable(s:history_file)
        let l:history_s = join(readfile(s:history_file), '')
        let s:history = json_decode(l:history_s) 
    else
        let s:history = []
    endif
endfunction

function! s:clear_history()
    let s:history = []
    call s:save_history()
endfunction

function! s:save_history()
    let l:history_text = json_encode(s:history)
    silent! call writefile([l:history_text], s:history_file)
endfunction

""""""
" jobs
function! s:save_job(job_id)
  let s:active_jobs += [a:job_id]
  if len(s:active_jobs) > s:n_jobs_cleanup
    for job_id in s:active_jobs[:]
        if job_info(job_id)['status'] == 'dead'
            call remove(s:active_jobs, index(s:active_jobs, job_id))
        endif
    endfor
  endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" appends message to local history and saves to file
function! s:append_message(msg_j)
    let l:msg  = copy(a:msg_j)
    if !has_key(l:msg, 'timestamp')
        let l:msg['timestamp'] = localtime()
    endif

    call add(s:history, l:msg)

    call s:save_history()

    return l:msg
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" llama_duo callbacks - with streaming
function! s:on_out_token(channel, msg)
    let bufnum = bufnr('vim_qna_chat')
    let json_string = substitute(a:msg, '^data: ', '', '')
    let response = json_decode(json_string)
    if has_key(response.choices[0].delta, 'content')
        let next_token = response.choices[0].delta.content
        let curr_line = getbufoneline(bufnum, '$')
        silent! call setbufline(bufnum, '$', split(curr_line . next_token . "\n", '\n'))
        let s:current_reply = s:current_reply . next_token
    endif
    " TODO: not move the cursor here so I can copy/paste?
    "silent! call win_execute(bufwinid('vim_qna_chat'), 'normal! G')
endfunction

function! s:prime_local(question)
    let req = {}
    let req.n_predict = g:vqna_max_tokens
    let req.messages  = s:history + [{"role": "user", "content": a:question}]
    let req.complete  = v:false
    " TODO - server should not need that
    let req.session_id = 10001

    let json_req = json_encode(req)
    let json_req = substitute(json_req, "'", "'\\\\''", "g")

    let curl_cmd  = "curl --no-buffer -s -X POST '" . g:vqna_llama_duo . "'"
    let curl_cmd .= " -H 'Content-Type: application/json'"
    let curl_cmd .= " -d '" . json_req . "'"

    call s:save_job(job_start(['/bin/sh', '-c', curl_cmd]))
endfunction

function! s:on_close(channel)
    call s:append_message({"role": "assistant", "content": s:current_reply})
    let s:current_reply = ""
endfunction

function! s:on_err(channel, msg)
    " TODO: logging
endfunction

" assumes the last message is already in history
function! s:ask_local()
    let req = {}
    let req.n_predict = g:vqna_max_tokens
    let req.messages  = s:history
    let req.complete  = v:true
    " TODO - server should not need that
    let req.session_id = 10001

    let json_req = json_encode(req)
    let json_req = substitute(json_req, "'", "'\\\\''", "g")

    let curl_cmd  = "curl --no-buffer -s -X POST '" . g:vqna_llama_duo . "'"
    let curl_cmd .= " -H 'Content-Type: application/json'"
    let curl_cmd .= " -d '" . json_req . "'"

    let s:current_reply = ""
    let l:job_conf = {'out_cb': 's:on_out_token', 'err_cb': 's:on_err', 'close_cb': 's:on_close'}
    call s:save_job(job_start(['/bin/sh', '-c', curl_cmd], l:job_conf))

    let bufnum = bufnr('vim_qna_chat')

    " we are not printing from history, but stream tokens one by one
    let prompt = strftime("%H:%M:%S Local: ")
    call appendbufline(bufnum, line('$'), prompt)
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

function! s:fmt_question(context, question)
    return "Here's a code snippet: \n\n " . a:context . "\n\n" . a:question
endfunction

function! s:qq_prepare()
    let l:context = s:get_visual_selection()
    if !empty(l:context)
        call timer_start(0, { -> s:preprocess(l:context) })
    endif
    call feedkeys(":'<,'>QQ ", 'n')
endfunction

function! s:preprocess(context)
    let l:prompt = s:fmt_question(a:context, "")
    call s:prime_local(l:prompt)
endfunction

function! s:ask_with_context(question)
    let l:context = s:get_visual_selection()
    if l:context == ''
        let l:question = a:question
    else
        let l:question = s:fmt_question(l:context, a:question)
    endif
    let l:message  = {"role": "user", "content": l:question}
    " timestamp and other metadata might get appended here
    let l:message  = s:append_message(l:message)
    call s:print_message(v:true, l:message)
    call s:ask_local()
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" utilities for buffer/chat manipulation
function! s:open_chat()
    " Check if the buffer already exists
    let bufnum = bufnr('vim_qna_chat')
    if bufnum == -1
        " Create a new buffer in a vertical split
        silent! execute 'topleft vertical ' . g:qq_width . ' new'
        silent! execute 'edit vim_qna_chat'
        setlocal buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
    else
        let winnum = bufwinnr(bufnum)
        if winnum == -1
            silent! execute 'topleft vertical ' . g:qq_width . ' split'
            silent! execute 'buffer ' bufnum
        else
            silent! execute winnum . 'wincmd w'
        endif
    endif
endfunction

function! s:toggle_chat_window()
    let bufnum = bufnr('vim_qna_chat')
    if bufnum == -1
        call s:open_chat()
    else
        let l:winid = bufwinid('vim_qna_chat')
        if l:winid != -1
            call win_gotoid(l:winid)
            silent! execute 'hide'
        else
            call s:open_chat()
        endif
    endif
endfunction

" appends a single message to the buffer
function! s:print_message(open_chat, message)
    if a:open_chat
        call s:open_chat()
    endif

    let l:tstamp = "        "
    if has_key(a:message, 'timestamp')
        let l:tstamp = strftime("%H:%M:%S ", a:message['timestamp'])
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

function! s:load_from_history()
    call s:load_history()
    call s:open_chat()

    call deletebufline('%', 1, '$')

    for msg in s:history
        call s:print_message(v:false, msg)
    endfor
endfunction

function! s:new_session()
    call s:clear_history()
    call s:load_from_history()
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" basic color scheme setup
function! s:setup_syntax()
    syntax clear

    syntax match localPrompt   "^\d\d:\d\d:\d\d\s*Local:"  nextgroup=restOfLine
    syntax match sonnetPrompt  "^\d\d:\d\d:\d\d\s*Sonnet:" nextgroup=restOfLine

    syntax match userTagPrompt "^\d\d:\d\d:\d\d\s*You:\s"  nextgroup=taggedBot
    syntax match taggedBot     "\(@Local\|@Sonnet\)"       nextgroup=restOfLine

    syntax match restOfLine ".*$" contained

    highlight localPrompt   cterm=bold gui=bold
    highlight sonnetPrompt  cterm=bold gui=bold
    highlight userTagPrompt cterm=bold gui=bold
    highlight taggedBot     ctermfg=DarkBlue guifg=DarkBlue
endfunction


augroup VQQSyntax
  autocmd!
  autocmd BufRead,BufNewFile *vim_qna_chat* call s:setup_syntax()
augroup END


" -------------------------------------------------- "
xnoremap <silent> QQ :<C-u>call <SID>qq_prepare()<CR>
nnoremap <leader>qq :call <SID>toggle_chat_window()<CR>
nnoremap <leader>ll :call <SID>load_from_history()<CR>
nnoremap <leader>qn :call <SID>new_session()<CR>

" Define your custom command
command! -range -nargs=+ QQ call s:ask_with_context(<q-args>)
