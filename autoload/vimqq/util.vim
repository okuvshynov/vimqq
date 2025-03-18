if exists('g:autoloaded_vimqq_util_module')
    finish
endif

let g:autoloaded_vimqq_util_module = 1

let s:ROOT = expand('<sfile>:p:h:h:h')

" This is plugin root. Use this to refer to plugin files, prompts, etc
function! vimqq#util#root() abort
    return s:ROOT
endfunction

function! vimqq#util#merge(d1, d2) abort
  let result = {}
  
  " First copy all keys from d1
  for [key, value] in items(a:d1)
    let result[key] = value
  endfor

  " Then merge with d2, summing up values for existing keys
  for [key, value] in items(a:d2)
    let result[key] = get(result, key, 0) + value
  endfor

  return result
endfunction

" Absolutely no magic replacement
function! vimqq#util#replace(source, from, to)
    let idx_byte = stridx(a:source, a:from, 0)
    if idx_byte == -1
        return copy(a:source)
    endif
    let len_bytes = strlen(a:from)
    let pos_bytes = idx_byte + len_bytes
    let prefix = ''
    if idx_byte > 0
        let prefix = a:source[0 : idx_byte - 1]
    endif
    return prefix . a:to . a:source[pos_bytes : ]
endfunction

" Needed for unit tests only
function! vimqq#util#has_flask(python_cmd)
    if empty(a:python_cmd)
        return 0
    endif
    
    " Use pip to check if flask is installed
    let flask_check = system(a:python_cmd . ' -m pip list | grep -i flask')
    return v:shell_error == 0
endfunction

" Needed for unit tests only
function! vimqq#util#has_python()
    " Try python3 first
    let python3_version = system('python3 --version 2>&1')
    if v:shell_error == 0
		if vimqq#util#has_flask('python3')
        	return 'python3'
		endif
    endif
    
    " Then try python (which might be python3 on some systems)
    let python_version = system('python --version 2>&1')
    if v:shell_error == 0
		if vimqq#util#has_flask('python')
        	return 'python'
		endif
    endif
    
    return ''
endfunction

function! vimqq#util#log_msg(msg)
    call vimqq#log#debug(' msg.seq_id = ' . get(a:msg, 'seq_id', 'NONE'))
    call vimqq#log#debug('  msg.role = ' . get(a:msg, 'role', 'NONE'))
    if has_key(a:msg, 'content')
        call vimqq#log#debug('  msg.content.len = ' . len(a:msg.content))
        for content in a:msg.content
            call vimqq#log#debug('  content.type = ' . get(content, 'type', 'NONE'))
        endfor
    else
        call vimqq#log#debug('  msg.content = NONE')
    endif
endfunction

function! vimqq#util#log_chat(chat)
    call vimqq#log#debug('chat.id = ' . get(a:chat, 'id', 'NONE'))
    if has_key(a:chat, 'messages')
        for msg in a:chat.messages
            call vimqq#util#log_msg(msg)
        endfor
    else
        call vimqq#log#debug(' chat.messages = NONE')
    endif
    if has_key(a:chat, 'partial_message')
        call vimqq#log#debug(' chat.partial_message:')
        call vimqq#util#log_msg(a:chat.partial_message)
    else
        call vimqq#log#debug(' chat.partial_message = NONE')
    endif
endfunction

" Check if a file path matches any pattern in the given list
" Similar to gitignore pattern matching
" Returns 1 if path matches any pattern, 0 otherwise
function! vimqq#util#path_matches_patterns(path, patterns) abort
    call vimqq#log#debug('path: ' . a:path)
    call vimqq#log#debug('patterns: ' . string(a:patterns))
    if empty(a:patterns)
        return 0
    endif

    " Normalize the path (ensure forward slashes)
    let path = substitute(a:path, '\', '/', 'g')
    
    for pattern in a:patterns
        " Skip empty lines and comments
        if empty(pattern) || pattern =~# '^#'
            continue
        endif
        
        " Handle negation (patterns starting with !)
        let negated = 0
        let pat = pattern
        if pat =~# '^!'
            let negated = 1
            let pat = pat[1:]
        endif
        
        " Trim leading and trailing whitespace
        let pat = substitute(pat, '^\s\+\|\s\+$', '', 'g')
        if empty(pat)
            continue
        endif
        
        " Simple wildcard matching (convert to regex)
        let pat_regex = pat
        
        " Handle exact directory matching (ending with /)
        let is_dir_only = pat_regex =~# '/$'
        if is_dir_only
            let pat_regex = substitute(pat_regex, '/$', '', 'g')
        endif
        
        " Convert * to regex wildcard (any chars)
        let pat_regex = substitute(pat_regex, '\*', '.*', 'g')
        
        " Convert ? to regex wildcard (single char)
        let pat_regex = substitute(pat_regex, '?', '.', 'g')
        
        " Perform the match (basic implementation)
        let matched = path =~# pat_regex . '$'
        
        " If pattern starts with /, match only from beginning
        if pat =~# '^/'
            let pat_no_slash = substitute(pat, '^/', '', '')
            let matched = path =~# '^' . pat_no_slash
        endif
        
        " For directory-only patterns, check if path is a directory
        if is_dir_only
            " Simple check - in a real implementation would use filereadable/isdirectory
            let is_dir = path =~# '/$'
            let matched = matched && is_dir
        endif
        
        " If negated, invert the match
        if negated
            let matched = !matched
        endif
        
        if matched
            return 1
        endif
    endfor
    
    return 0
endfunction
