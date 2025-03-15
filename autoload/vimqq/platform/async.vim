if exists('g:autoloaded_vimqq_async_module')
    finish
endif

let g:autoloaded_vimqq_async_module = 1

" Promise states
let s:PENDING = 0
let s:FULFILLED = 1
let s:REJECTED = 2

function vimqq#platform#async#promise(executor) abort
    let promise = {
        \ 'state': s:PENDING,
        \ 'value': v:null,
        \ 'reason': v:null,
        \ 'then_callbacks': [],
        \ 'catch_callbacks': []
    \ }

	function! promise.resolve(value) abort closure
        call vimqq#log#debug('RESOLVE CALLED')
		if self.state != s:PENDING | return | endif
		let self.state = s:FULFILLED
		let self.value = a:value
		call s:schedule_callbacks(self)
	endfunction

	function! promise.reject(reason) abort closure
		if self.state != s:PENDING | return | endif
		let self.state = s:REJECTED
		let self.reason = a:reason
		call s:schedule_callbacks(self)
	endfunction

	function! promise.then(onFulfilled, ...) abort closure
		let l:onRejected = a:0 > 0 ? a:1 : v:null

		" Create a new promise for chaining
		let l:next_promise = vimqq#platform#async#promise({res, rej -> 0})

		" Store callbacks with their target promise
		call add(self.then_callbacks, [a:onFulfilled, l:next_promise])

		" If onRejected provided, use it for error handling
		if l:onRejected isnot v:null
			call add(self.catch_callbacks, [l:onRejected, l:next_promise])
		endif

		" If already resolved/rejected, schedule callbacks
		if self.state != s:PENDING
			call s:schedule_callbacks(self)
		endif

		return l:next_promise
	endfunction

	function! promise.catch(onRejected) abort closure
		return self.then(v:null, a:onRejected)
	endfunction

	try
		call a:executor(promise.resolve, promise.reject)
	catch
		call promise.reject(v:exception)
	endtry

	return promise
endfunction

function! s:schedule_callbacks(promise) abort
    call vimqq#log#debug('schedule_callbacks called')
	call timer_start(0, {-> s:execute_callbacks(a:promise)})
endfunction

function! s:execute_callbacks(promise) abort
    call vimqq#log#debug('execute_callbacks called')
    call vimqq#log#debug('promise state: ' . a:promise.state)
	if a:promise.state == s:FULFILLED
        call vimqq#log#debug('promise fulfilled')
        call vimqq#log#debug('callbacks: ' . len(a:promise.then_callbacks))
		" Execute then callbacks
		for then_callback in a:promise.then_callbacks
            call vimqq#log#debug('trying callback: ' . string(then_callback))
            let Callback = then_callback[0]
            let next_promise = then_callback[1]
			if Callback isnot v:null
				try
                    call vimqq#log#debug('trying resolve')
					call next_promise.resolve(Callback(a:promise.value))
				catch
					call next_promise.reject(v:exception)
				endtry
			else
                call vimqq#log#debug('is null')
				" Pass through value if no callback
				call next_promise.resolve(a:promise.value)
			endif
		endfor

		" Clear the callbacks after execution
		let a:promise.then_callbacks = []
	elseif a:promise.state == s:REJECTED
		" Check if we have catch callbacks
		if !empty(a:promise.catch_callbacks)
	  		for [Callback, next_promise] in a:promise.catch_callbacks
				try
		  			call next_promise.resolve(Callback(a:promise.reason))
				catch
		  			call next_promise.reject(v:exception)
				endtry
	  		endfor
		else
		  	" Propagate rejection to next promises
		  	for [_, next_promise] in a:promise.then_callbacks
				call next_promise.reject(a:promise.reason)
		  	endfor
		endif

		" Clear the callbacks
		let a:promise.catch_callbacks = []
		let a:promise.then_callbacks = []
	endif
endfunction

function! vimqq#platform#async#delay(ms) abort
    let delay_ms = a:ms
	return vimqq#platform#async#promise({resolve, _ ->
        \ timer_start(delay_ms, {_ -> resolve(delay_ms)})
        \ })
endfunction
