if exists('g:autoloaded_vimqq_str_module')
    finish
endif

let g:autoloaded_vimqq_str_module = 1

" Absolutely no magic replacement
function! vimqq#str#replace(source, from, to)
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
