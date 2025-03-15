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

function! vimqq#util#capture()
	let capture = {'value': 0}

	function! capture.set(v) dict
		let self.value = a:v
		return a:v
	endfunction

	function! capture.get() dict
		return self.value
	endfunction

	return capture
endfunction

