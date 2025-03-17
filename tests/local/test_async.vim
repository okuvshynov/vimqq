let s:suite = themis#suite('test_async.vim')
let s:assert = themis#helper('assert')

let s:path = expand('<sfile>:p:h') . '/test_dir'

function s:suite.test_delay()
	let c = vimqq#util#capture()

    call vimqq#async#delay(50).then({t -> c.set(t)})

    :sleep 100m

    call s:assert.equals(c.get(), 50)
endfunction

function s:suite.test_job()
	let c = vimqq#util#capture()

    call vimqq#async#job(['ls', s:path]).then({t -> c.set(t)})

    :sleep 100m

    call s:assert.equals(c.get()['stdout'], ['a.txt', 'b.txt'])
    call s:assert.equals(c.get()['status'], 0)
endfunction

function s:suite.test_chain()
	let c = vimqq#util#capture()

    call vimqq#async#job(['ls', s:path])
    \     .then({t -> vimqq#async#job(['cat', t['stdout'][1]])})

    :sleep 100m

    call s:assert.equals(c.get()['stdout'], ['b content'])
    call s:assert.equals(c.get()['status'], 0)
endfunction
