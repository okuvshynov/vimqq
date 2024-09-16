" Prevents the script from being loaded multiple times
if exists('g:autoloaded_vimqq_bot_base_module')
    finish
endif

let g:autoloaded_vqq_bot_base_module = 1

" Creates a new base object with callback management functionality
function! vimqq#bots#base#new() abort
    let l:base = {}
    let l:base._callbacks = {}

    " Sets a callback function for a given key
    function! l:base.set_cb(key, fn) dict
        if type(a:fn) != v:t_func
            throw 'vimqq#base: callback must be a function'
        endif
        let self._callbacks[a:key] = a:fn
    endfunction

    " Calls a callback function for a given key with optional arguments
    function! l:base.call_cb(key, ...) dict
        if has_key(self._callbacks, a:key)
            return call(self._callbacks[a:key], a:000)
        endif
    endfunction

    return l:base
endfunction
