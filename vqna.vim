" Copyright 2024 Oleksandr Kuvshynov


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" configuration one can do in vimrc
" shared config
let g:vqna_max_tokens = get(g:, 'vqna_max_tokens', 1024)

" anthropic-specific config
let g:vqna_api_key    = get(g:, 'vqna_api_key'   , $ANTHROPIC_API_KEY)
let g:vqna_model_name = get(g:, 'vqna_model_name', "claude-3-5-sonnet-20240620")

" local llama.cpp server config
let g:vqna_local_addr = get(g:, 'vqna_local_addr', "http://localhost:8080/chat/completions")


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" this is the interface 
" QQ[L|S][?C]
" QQL - quick question local
" QQSC - quick question sonnet with context
command! -nargs=1        QQL  :call s:ask("local", <q-args>)
command! -range -nargs=1 QQLC :call s:ask_with_context("local", <q-args>)
command! -nargs=1        QQS  :call s:ask("anthropic", <q-args>)
command! -range -nargs=1 QQSC :call s:ask_with_context("anthropic", <q-args>)


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" local state
let s:job_id = 0
let s:curr   = []


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


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Anthropic callbacks - no streaming
function! s:on_out(channel, msg)
    call add(s:curr, a:msg)
endfunction

function! s:on_exit(job_id, exit_status)
    let response = json_decode(join(s:curr, '\n'))
    call s:open_chat()
    let ai_prompt = strftime("%H:%M:%S Sonnet: ")
    let reply     = ai_prompt . response.content[0].text
    call append(line('$'), split(reply, "\n"))
    normal! G
endfunction

function! s:ask_anthropic(question)
    let req = {}
    let req.model      = g:vqna_model_name
    let req.max_tokens = g:vqna_max_tokens
    let req.messages   = [{"role": "user", "content": a:question}]

    let json_req = json_encode(req)
    let json_req = substitute(json_req, "'", "'\\\\''", "g")

    let curl_cmd  = "curl -s -X POST 'https://api.anthropic.com/v1/messages'"
    let curl_cmd .= " -H 'Content-Type: application/json'"
    let curl_cmd .= " -H 'x-api-key: " . g:vqna_api_key . "'"
    let curl_cmd .= " -H 'anthropic-version: 2023-06-01'"
    let curl_cmd .= " -d '" . json_req . "'"

    let s:curr = []
    let s:job_id = job_start(['/bin/sh', '-c', curl_cmd], {'out_cb': 's:on_out', 'exit_cb': 's:on_exit'})
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" llama.cpp callbacks - with streaming
function! s:on_out_token(channel, msg)
    if a:msg !~# '^data: '
        return
    endif
    let bufnum = bufnr('vim_qna_chat')
    let json_string = substitute(a:msg, '^data: ', '', '')
    let response = json_decode(json_string)
    if has_key(response.choices[0].delta, 'content')
        let next_token = response.choices[0].delta.content
        let curr_line = getbufoneline(bufnum, '$')
        call setbufline(bufnum, '$', split(curr_line . next_token . "\n", '\n'))
    endif
endfunction

function! s:ask_local(question)
    let req = {}
    let req.n_predict = g:vqna_max_tokens
    let req.messages  = [{"role": "user", "content": a:question}]
    let req.stream    = v:true

    let json_req = json_encode(req)
    let json_req = substitute(json_req, "'", "'\\\\''", "g")

    let curl_cmd  = "curl --no-buffer -s -X POST '" . g:vqna_local_addr . "'"
    let curl_cmd .= " -H 'Content-Type: application/json'"
    let curl_cmd .= " -d '" . json_req . "'"

    let s:job_id = job_start(['/bin/sh', '-c', curl_cmd], {'out_cb': 's:on_out_token'})

    let bufnum = bufnr('vim_qna_chat')
    let prompt = strftime("%H:%M:%S  Local: ")
    call appendbufline(bufnum, line('$'), prompt)
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" picking the implementation
let s:backend_impl = {
  \ 'anthropic' : {
  \   'ask'  : function('s:ask_anthropic'),
  \   'name' : 'Sonnet',
  \ },
  \ 'local' : {
  \   'ask'  : function('s:ask_local'),
  \   'name' : 'Local',
  \ },
\ }

function! s:ask_impl(backend, question)
    return s:backend_impl[a:backend]['ask'](a:question)
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" top-level functions called by commands defined below
function! s:ask(backend, question)
    call s:print_question(a:backend, a:question)
    call s:ask_impl(a:backend, a:question)
endfunction

function! s:ask_with_context(backend, question)
    " Get the selected lines
    let line_a = getpos("'<")[1]
    let line_b = getpos("'>")[1]
    let lines  = getline(line_a, line_b)

    " Basic prompt format
    let prompt = "Here's a code snippet: \n\n " . join(lines, '\n') . "\n\n" . a:question
    call s:print_question(a:backend, a:question)
    call s:ask_impl(a:backend, prompt)
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" utilities for buffer/chat manipulation
function! s:open_chat()
    " Check if the buffer already exists
    let bufnum = bufnr('vim_qna_chat')
    if bufnum == -1
        " Create a new buffer in a vertical split
        execute 'vsplit vim_qna_chat'
        setlocal buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
    else
        let winnum = bufwinnr(bufnum)
        if winnum == -1
            execute 'vsplit | buffer' bufnum
        else
            execute winnum . 'wincmd w'
        endif
    endif
endfunction

augroup VQQSyntax
  autocmd!
  autocmd BufRead,BufNewFile *vim_qna_chat* call s:setup_syntax()
augroup END

function! s:print_question(backend, question)
    call s:open_chat()

    let backend_title = s:backend_impl[a:backend]['name']

    if line('$') > 1
        call append(line('$'), repeat('-', 80))
    endif

    let you_prompt = strftime("%H:%M:%S    You: @" . backend_title. " ")
    call append(line('$'), you_prompt . a:question)

    normal! G
endfunction
