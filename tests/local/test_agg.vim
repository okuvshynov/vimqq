let s:suite = themis#suite('Test aggregation')
let s:assert = themis#helper('assert')

function! s:suite.test_merge() abort
  let d1 = {'a': 1, 'b': 2}
  let d2 = {'b': 3, 'c': 4}
  
  let result = vimqq#agg#merge(d1, d2)

  call s:assert.equals(result['a'], 1)
  call s:assert.equals(result['b'], 5)
  call s:assert.equals(result['c'], 4)
endfunction

function! s:suite.test_merge_empty() abort
  let d1 = {}
  let d2 = {'a': 1}
  
  let result = vimqq#agg#merge(d1, d2)
  call s:assert.equals(result['a'], 1)

  let result = vimqq#agg#merge(d2, d1)
  call s:assert.equals(result['a'], 1)
endfunction

function! s:suite.test_merge_non_existent() abort
  let d1 = {'a': 1}
  let d2 = {'b': 2}
  
  let result = vimqq#agg#merge(d1, d2)
  call s:assert.equals(result['a'], 1)
  call s:assert.equals(result['b'], 2)
  call s:assert.equals(get(result, 'c', 0), 0)
endfunction
