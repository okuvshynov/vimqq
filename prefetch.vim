" Copyright 2024 Oleksandr Kuvshynov


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" configuration one can do in vimrc
" shared config
let g:vqna_max_tokens = get(g:, 'vqna_max_tokens', 1024)

" local llama_duo server config
let g:vqna_llama_duo = get(g:, 'vqna_llama_duo', "http://localhost:5555/query")

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" local state
let s:job_id = 0

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
" llama_duo callbacks - with streaming
function! s:on_out_token(channel, msg)
    let bufnum = bufnr('vim_qna_chat')
    let json_string = substitute(a:msg, '^data: ', '', '')
    let response = json_decode(json_string)
    if has_key(response.choices[0].delta, 'content')
        let next_token = response.choices[0].delta.content
        let curr_line = getbufoneline(bufnum, '$')
        call setbufline(bufnum, '$', split(curr_line . next_token . "\n", '\n'))
    endif
endfunction

function! s:prime_local(question)
    let req = {}
    let req.n_predict = g:vqna_max_tokens
    let req.messages  = [{"role": "user", "content": a:question}]
    let req.complete  = v:false

    let json_req = json_encode(req)
    let json_req = substitute(json_req, "'", "'\\\\''", "g")

    let curl_cmd  = "curl --no-buffer -s -X POST '" . g:vqna_llama_duo . "'"
    let curl_cmd .= " -H 'Content-Type: application/json'"
    let curl_cmd .= " -d '" . json_req . "'"

    let s:prime_job_id = job_start(['/bin/sh', '-c', curl_cmd])
endfunction

function! s:ask_local(question)
    let req = {}
    let req.n_predict = g:vqna_max_tokens
    let req.messages  = [{"role": "user", "content": a:question}]
    let req.complete  = v:true

    let json_req = json_encode(req)
    let json_req = substitute(json_req, "'", "'\\\\''", "g")

    let curl_cmd  = "curl --no-buffer -s -X POST '" . g:vqna_llama_duo . "'"
    let curl_cmd .= " -H 'Content-Type: application/json'"
    let curl_cmd .= " -d '" . json_req . "'"

    "let output = system('/bin/sh -c ' . shellescape(curl_cmd))

    let s:job_id = job_start(['/bin/sh', '-c', curl_cmd], {'out_cb': 's:on_out_token', 'err_cb': 's:on_out_token'})

    let bufnum = bufnr('vim_qna_chat')
    let prompt = strftime("%H:%M:%S  Local: ")
    call appendbufline(bufnum, line('$'), prompt)
endfunction

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

function! s:fmt_question(context, question)
    return "Here's a code snippet: \n\n " . a:context . "\n\n" . a:question
endfunction

function! s:preprocess(timer)
    let prompt = s:fmt_question(s:visual_selection, "")
    call s:prime_local(prompt)
endfunction

function! s:ask_with_context(question)
    let prompt = s:fmt_question(s:visual_selection, a:question)
    call s:print_question(a:question)
    call s:ask_local(prompt)
endfunction

xnoremap <silent> QQ :<C-u>call <SID>start_prefetch()<CR>

" Define your custom command
command! -range -nargs=+ QQ call s:ask_with_context(<q-args>)

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

function! s:print_question(question)
    call s:open_chat()

    let backend_title = 'Local'

    if line('$') > 1
        call append(line('$'), repeat('-', 80))
    endif

    let you_prompt = strftime("%H:%M:%S    You: @" . backend_title. " ")
    call append(line('$'), you_prompt . a:question)

    normal! G
endfunction