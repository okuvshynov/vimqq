let s:suite = themis#suite('test_async.vim')
let s:assert = themis#helper('assert')

function s:suite.test_delay()
	let c = vimqq#util#capture()

    call vimqq#platform#async#delay(50).then({t -> c.set(t)})

    :sleep 100m

    call s:assert.equals(c.get(), 50)
endfunction
