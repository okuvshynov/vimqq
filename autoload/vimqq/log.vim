" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_log')
    finish
endif

let g:autoloaded_vimqq_log = 1

let g:vqq_log_file = get(g:, 'vqq_log_file', vimqq#platform#path#log('vimqq.log'))
let g:vqq_log_level = get(g:, 'vqq_log_level', 'INFO')
let g:vqq_log_format = get(g:, 'vqq_log_format', '%Y-%m-%d %H:%M:%S ')

let s:LOG_LEVELS = {
    \ 'DEBUG': 0,
    \ 'INFO': 1,
    \ 'WARNING': 2,
    \ 'ERROR': 3,
    \ 'NONE': 4
\ }

" TODO: For file:line tracking
"   - lambdas can have line off by one
"   - calling from script might not work at all

function s:log_impl(level, message)
    if s:LOG_LEVELS[a:level] < s:LOG_LEVELS[g:vqq_log_level]
        return
    endif

    let stack = split(expand('<stack>'), '\.\.')
    " stack will look like this:
    " 0: ...
    " ...
    " n - 3: callsite we care about
    " n - 2: vimqq#log#...
    " n - 1: s:log_impl
    let callsite = ''
    if len(stack) > 2
        let [file_path, line_num] = s:parse_function(stack[len(stack) - 3])
        if line_num > 0
            let file_name = fnamemodify(file_path, ':t')
            let callsite = file_name . ':' . line_num . ' '
        endif
    endif

    let message = a:level[0] . strftime(g:vqq_log_format) . callsite . a:message
    call writefile([message], g:vqq_log_file, "a")
    let level_log_file = g:vqq_log_file . "." . a:level
    call writefile([message], level_log_file, "a")
endfunction

function! vimqq#log#error(message)
    call s:log_impl('ERROR', a:message)
endfunction

function! vimqq#log#info(message)
    call s:log_impl('INFO', a:message)
endfunction

function! vimqq#log#debug(message)
    call s:log_impl('DEBUG', a:message)
endfunction

function! vimqq#log#warning(message)
    call s:log_impl('WARNING', a:message)
endfunction

function! s:get_callsite()
    let l:stack = split(expand('<stack>'), '\.\.')
    for s in l:stack
        call s:parse_function(s)
    endfor
endfunction

function! s:parse_frame(frame)
    let matches = matchlist(a:frame, '^\(.*\)\[\(\d\+\)\]$')
    if len(matches) > 0
        return [matches[1], matches[2]]
    endif
    " fail to parse
    return ['', 0]
endfunction

function! s:parse_function(frame)
    let parsed = s:parse_frame(a:frame)
    if parsed[0] =~# '^function '
        let info = execute(':verbose ' . parsed[0])
        let local_line = parsed[1]
        let info_list = split(info, "\n")
        for i in info_list
            let matches = matchlist(i, '^\tLast set from \(.*\) line \(\d\+\)$')
            if len(matches) > 0
                let definition_line = matches[2]
                return [matches[1], string(local_line + definition_line)]
            endif
        endfor
    endif

    " handle numbered function
    if parsed[0] =~# '^\d\+$'
        let info = execute(':verbose function g:' . parsed[0])
        let local_line = parsed[1]
        let info_list = split(info, "\n")
        for i in info_list
            let matches = matchlist(i, '^\tLast set from \(.*\) line \(\d\+\)$')
            if len(matches) > 0
                let definition_line = matches[2]
                return [matches[1], string(local_line + definition_line)]
            endif
        endfor
    endif

    " assume entire thing is function name
    " also handles <SNR>ddfn[...]
    try
        let info = execute(':verbose function ' . parsed[0])
        let local_line = parsed[1]
        let info_list = split(info, "\n")
        for i in info_list
            let matches = matchlist(i, '^\tLast set from \(.*\) line \(\d\+\)$')
            if len(matches) > 0
                let definition_line = matches[2]
                return [matches[1], string(local_line + definition_line)]
            endif
        endfor
    endtry
    return ['', 0]
endfunction

" we need this function so that for debugging purposes we can get it and
" force this module to be loaded, thus using the default value if 
" it wasn't configured
function! vimqq#log#file()
    return g:vqq_log_file
endfunction
