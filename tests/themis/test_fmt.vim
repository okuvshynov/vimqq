let s:suite = themis#suite('Unit tests for prompt formatting')
let s:assert = themis#helper('assert')

function s:suite.test_context()
    call s:assert.equals(3, 1 + 2)
endfunction
