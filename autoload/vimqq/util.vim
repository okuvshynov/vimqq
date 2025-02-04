if exists('g:autoloaded_vimqq_util_module')
    finish
endif

let g:autoloaded_vimqq_util_module = 1

function! vimqq#util#root() abort
    return expand('<script>:p:h:h:h')
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
