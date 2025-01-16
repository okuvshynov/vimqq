if exists('g:autoloaded_vimqq_model')
    finish
endif

let g:autoloaded_vimqq_model = 1

let s:observers = []

function! vimqq#events#set_state(state) abort
    let s:state = a:state
endfunction

function! vimqq#events#clear_observers() abort
    let s:observers = []
endfunction

function! vimqq#events#add_observer(observer) abort
    call add(s:observers, a:observer)
endfunction

function! vimqq#events#notify(event, context) abort
    call vimqq#log#debug('event: ' . a:event)
    let a:context['state'] = v:null
    call vimqq#log#debug('context: ' . string(a:context))
    let a:context['state'] = s:state
    for observer in s:observers
        call observer.handle_event(a:event, a:context)
    endfor
endfunction
