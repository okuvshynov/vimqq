if exists('g:autoloaded_vimqq_checksum_module')
    finish
endif

let g:autoloaded_vimqq_checksum_module = 1

" TODO: this is likely vim 8.2+
function! vimqq#platform#checksum#sha256(file)
  let content = join(readfile(a:file, 'b'), "\n")
  return sha256(content)
endfunction

