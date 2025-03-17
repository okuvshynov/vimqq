"if exists('g:autoloaded_vimqq_async_module')
"    finish
"endif

let g:autoloaded_vimqq_async_module = 1

" Promise states
let s:PENDING = 0
let s:FULFILLED = 1
let s:REJECTED = 2

function! vimqq#async#promise(executor) abort
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

	function! promise.then(onFulfilled, ...) abort dict
		let l:onRejected = a:0 > 0 ? a:1 : v:null

		" Create a new promise for chaining
		let l:next_promise = vimqq#async#promise({res, rej -> 0})

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
    call vimqq#log#debug('promise state: ' . a:promise.state)
	if a:promise.state == s:FULFILLED
        call vimqq#log#debug('n_callbacks: ' . len(a:promise.then_callbacks))
		" Execute then callbacks
		for [Callback, next_promise] in a:promise.then_callbacks
			if Callback isnot v:null
				try
					call next_promise.resolve(Callback(a:promise.value))
				catch
					call next_promise.reject(v:exception)
				endtry
			else
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
		  	for [Callback, next_promise] in a:promise.then_callbacks
				call next_promise.reject(a:promise.reason)
		  	endfor
		endif

		" Clear the callbacks
		let a:promise.catch_callbacks = []
		let a:promise.then_callbacks = []
	endif
endfunction

function! vimqq#async#delay(ms) abort
    let delay_ms = a:ms
	return vimqq#async#promise({resolve, _ ->
        \ timer_start(delay_ms, {_ -> resolve(delay_ms)})
        \ })
endfunction

function! vimqq#async#job(cmd) abort
    let executor = {}
    function! executor.start(command, Resolve, Reject) dict
        call vimqq#log#debug('executor starts: ' . string(a:command))
        let job_data = {
          \ 'stdout': [],
          \ 'stderr': [],
          \ 'exit_status': v:null
        \ }
        let job_options = {
          \ 'out_mode': 'nl',
          \ 'err_mode': 'nl',
          \ 'callback': {channel, msg -> add(job_data.stdout, msg)},
          \ 'err_cb': {channel, msg -> add(job_data.stderr, msg)},
          \ 'exit_cb': {job, status -> s:handle_job_exit(status, l:job_data, a:Resolve, a:Reject)}
        \ }
        
        let l:job_started = vimqq#platform#jobs#start(a:command, job_options)
        if !l:job_started
            call a:reject('Failed to start job: ' . string(a:command))
        endif
    endfunction

  	return vimqq#async#promise({resolve, reject -> executor.start(a:cmd, resolve, reject)})
endfunction

" Handle job completion
function! s:handle_job_exit(status, job_data, resolve, reject) abort
    let a:job_data.exit_status = a:status
  
    let l:result = {
        \ 'stdout': a:job_data.stdout,
        \ 'stderr': a:job_data.stderr,
        \ 'status': a:status
    \ }
  
    " Resolve or reject based on exit status
    if a:status == 0
        call a:resolve(l:result)
    else
        call a:reject(l:result)
    endif
endfunction

let s:path = expand('<sfile>:p:h') . '/tests/test_dir'
function! vimqq#async#demo()
	let c = vimqq#util#capture()

    call vimqq#async#job(['ls', s:path])
    \     .then({t -> vimqq#async#job(['cat', t['stdout'][1]])})
    \     .then({t -> vimqq#log#info('demo!')})
    :sleep 500m
endfunction
