if exists('g:autoloaded_vqq_base_module')
    finish
endif

let g:autoloaded_vqq_base_module = 1

let g:vqq#Base = {}

function! g:vqq#Base.new() dict
    let l:instance = copy(self)
    let l:instance._callbacks = {}
    return l:instance
endfunction

function! g:vqq#Base.set_cb(key, fn) dict
    let self._callbacks[a:key] = a:fn
endfunction

function! g:vqq#Base.call_cb(key, ...) dict
    if has_key(self._callbacks, a:key)
        return call(self._callbacks[a:key], a:000)
    endif
endfunction
