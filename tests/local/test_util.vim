let s:suite = themis#suite('test_util.vim')
let s:assert = themis#helper('assert')

function s:suite.test_basic()
    let observed = vimqq#util#replace("hello, world", "hello", "Hello")
    call s:assert.equals(observed, "Hello, world")
endfunction

function s:suite.test_unicode()
    let observed = vimqq#util#replace("▄hello, world", "hello", "Hello")
    call s:assert.equals(observed, "▄Hello, world")
endfunction

function s:suite.test_unicode_from()
    let observed = vimqq#util#replace("▄hello▂, world", "hello▂", "Hello")
    call s:assert.equals(observed, "▄Hello, world")
endfunction

function s:suite.test_no_magic()
    let observed = vimqq#util#replace("hello~world", "hello~", "Hello~, ")
    call s:assert.equals(observed, "Hello~, world")
endfunction

function s:suite.test_nl0()
    let observed = vimqq#util#replace("hello\nworld", "hello", "Hello")
    call s:assert.equals(observed, "Hello\nworld")
endfunction

function s:suite.test_nl1()
    let observed = vimqq#util#replace('hello\nworld', "hello", "Hello")
    call s:assert.equals(observed, 'Hello\nworld')
endfunction

function s:suite.test_nl2()
    let observed = vimqq#util#replace('hello\nworld', 'hello\n', 'Hello, ')
    call s:assert.equals(observed, 'Hello, world')
endfunction

function s:suite.test_nl3()
    let observed = vimqq#util#replace("hello\nworld", "hello\n", "Hello, ")
    call s:assert.equals(observed, "Hello, world")
endfunction

function s:suite.test_nl4()
    let observed = vimqq#util#replace('hello\nworld', "hello\n", 'Hello, ')
    call s:assert.equals(observed, 'hello\nworld')
endfunction

function s:suite.test_nl5()
    let observed = vimqq#util#replace("hello\nworld", 'hello\n', "Hello, ")
    call s:assert.equals(observed, "hello\nworld")
endfunction

function! s:suite.test_merge() abort
  let d1 = {'a': 1, 'b': 2}
  let d2 = {'b': 3, 'c': 4}
  
  let result = vimqq#util#merge(d1, d2)

  call s:assert.equals(result['a'], 1)
  call s:assert.equals(result['b'], 5)
  call s:assert.equals(result['c'], 4)
endfunction

function! s:suite.test_merge_empty() abort
  let d1 = {}
  let d2 = {'a': 1}
  
  let result = vimqq#util#merge(d1, d2)
  call s:assert.equals(result['a'], 1)

  let result = vimqq#util#merge(d2, d1)
  call s:assert.equals(result['a'], 1)
endfunction

function! s:suite.test_root() abort
  " the way we run it, project root should be current dir?
  let current = getcwd()
  let root = vimqq#util#root()
  
  call s:assert.equals(root, current)
endfunction

function! s:suite.test_merge_non_existent() abort
  let d1 = {'a': 1}
  let d2 = {'b': 2}
  
  let result = vimqq#util#merge(d1, d2)
  call s:assert.equals(result['a'], 1)
  call s:assert.equals(result['b'], 2)
  call s:assert.equals(get(result, 'c', 0), 0)
endfunction

function! s:suite.test_path_matches_patterns() abort
  " Test with empty patterns list
  call s:assert.equals(vimqq#util#path_matches_patterns('some/file.txt', []), 0)
  
  " Test exact filename match
  call s:assert.equals(vimqq#util#path_matches_patterns('file.txt', ['file.txt']), 1)
  call s:assert.equals(vimqq#util#path_matches_patterns('file.txt', ['other.txt']), 0)
  
  " Test wildcard patterns
  call s:assert.equals(vimqq#util#path_matches_patterns('file.txt', ['*.txt']), 1)
  call s:assert.equals(vimqq#util#path_matches_patterns('file.log', ['*.txt']), 0)
  
  " Test negated patterns
  call s:assert.equals(vimqq#util#path_matches_patterns('file.txt', ['!file.txt']), 0)
  call s:assert.equals(vimqq#util#path_matches_patterns('other.txt', ['!file.txt']), 1)
  
  " Test path normalization
  call s:assert.equals(vimqq#util#path_matches_patterns('src\file.txt', ['src/file.txt']), 1)
endfunction

function! s:suite.test_path_matches_patterns_dir() abort
    call s:assert.equals(vimqq#util#path_matches_patterns('foo/file.txt', ['foo/*']), 1)
    call s:assert.equals(vimqq#util#path_matches_patterns('bar/file.txt', ['foo/*']), 0)
endfunction
