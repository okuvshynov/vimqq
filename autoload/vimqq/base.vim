if exists('g:autoloaded_vimqq_base_module')
    finish
endif

let g:autoloaded_vqq_base_module = 1

function! vimqq#base#new() abort
    let l:base = {}
    let l:base._callbacks = {}
    function! l:base.set_cb(key, fn) dict
        if type(a:fn) != v:t_func
            throw 'vimqq#base: callback must be a function'
        endif
        let self._callbacks[a:key] = a:fn
    endfunction

    function! l:base.call_cb(key, ...) dict
        if has_key(self._callbacks, a:key)
            return call(self._callbacks[a:key], a:000)
        endif
    endfunction

    return l:base
endfunction
