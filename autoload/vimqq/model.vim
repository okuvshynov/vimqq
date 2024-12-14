if exists('g:autoloaded_vimqq_model')
    finish
endif

let g:autoloaded_vimqq_model = 1

let s:observers = []

function vimqq#model#add_observer(observer) abort
    call add(s:observers, a:observer)
endfunction

function vimqq#model#notify(event, context) abort
    call vimqq#log#debug('event: ' . a:event)
    for observer in s:observers
        call observer.handle_event(a:event, a:context)
    endfor
endfunction

