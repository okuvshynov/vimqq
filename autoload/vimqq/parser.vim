if exists('g:autoloaded_vimqq_parser')
    finish
endif
let g:autoloaded_vimqq_parser = 1

" Dictionary of supported context keys for QQ command
let s:qq_ctx_keys = {
    \ 's' : 'selection',
    \ 'f' : 'file',
    \ 'p' : 'project',
    \ 't' : 'ctags',
    \ 'b' : 'blame'
\}

" Dictionary of supported context keys for Q command
let s:q_ctx_keys = {
    \ 'f' : 'file',
    \ 'p' : 'project',
    \ 't' : 'ctags'
\}

function! vimqq#parser#parse_command(args, ctx_keys) abort
    call vimqq#log#debug(a:args)
    let args = split(a:args, ' ')
    let params = []

    " Parse optional params starting with '-'
    " For example, -nfw would mean 
    "  - send in [n]ew chat 
    "  - include current [f]ile as context
    "  - send a [w]armup query
    if len(args) > 0
        let param_match = matchlist(args[0], '^-\(.\+\)')
        if !empty(param_match)
            let params = split(param_match[1], '\zs')
            let args = args[1:]
        endif
    endif

    let l:message = join(args, ' ')
    let l:new_chat  = index(params, 'n') >= 0
    let l:do_warmup = index(params, 'w') >= 0

    let l:ctx_options = {}
    for [k, v] in items(a:ctx_keys)
        if index(params, k) >= 0
            let l:ctx_options[v] = 1
        endif
    endfor

    return {
        \ 'new_chat': l:new_chat,
        \ 'do_warmup': l:do_warmup,
        \ 'ctx_options': l:ctx_options,
        \ 'message': l:message
    \ }
endfunction

function! vimqq#parser#get_qq_ctx_keys() abort
    return s:qq_ctx_keys
endfunction

function! vimqq#parser#get_q_ctx_keys() abort
    return s:q_ctx_keys
endfunction

function! vimqq#parser#q(args) abort
    return vimqq#parser#parse_command(a:args, vimqq#parser#get_q_ctx_keys())
endfunction

function! vimqq#parser#qq(args) abort
    return vimqq#parser#parse_command(a:args, vimqq#parser#get_qq_ctx_keys())
endfunction
