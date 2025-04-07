if exists('g:autoloaded_vimqq_indexing_conf')
    finish
endif

let g:autoloaded_vimqq_indexing_conf = 1

" Load every time
function! vimqq#indexing#conf#get(key, default)
    let conf = vimqq#indexing#io#read('index.conf')
    return get(conf, a:key, a:default)
endfunction
