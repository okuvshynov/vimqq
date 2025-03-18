let s:suite = themis#suite('test_path_matches_patterns.vim')
let s:assert = themis#helper('assert')

function! s:suite.test_path_matches_patterns() abort
    " Test with empty patterns list
    call s:assert.equals(vimqq#util#path_matches_patterns('some/file.txt', []), 0)
    
    " Test exact filename match
    call s:assert.equals(vimqq#util#path_matches_patterns('file.txt', ['file.txt']), 1)
    call s:assert.equals(vimqq#util#path_matches_patterns('file.txt', ['other.txt']), 0)
    
    " Test * wildcard
    call s:assert.equals(vimqq#util#path_matches_patterns('file.txt', ['*.txt']), 1)
    call s:assert.equals(vimqq#util#path_matches_patterns('file.log', ['*.txt']), 0)
    
    " Test patterns with directories
    call s:assert.equals(vimqq#util#path_matches_patterns('src/file.txt', ['src/*.txt']), 1)
    call s:assert.equals(vimqq#util#path_matches_patterns('lib/file.txt', ['src/*.txt']), 0)
    
    " Test negated patterns
    call s:assert.equals(vimqq#util#path_matches_patterns('file.txt', ['!file.txt']), 0)
    call s:assert.equals(vimqq#util#path_matches_patterns('other.txt', ['!file.txt']), 1)
    
    " Test comments and whitespace
    let patterns = ['# This is a comment', '  file.txt  ']
    call s:assert.equals(vimqq#util#path_matches_patterns('file.txt', patterns), 1)
    call s:assert.equals(vimqq#util#path_matches_patterns('# This is a comment', patterns), 0)
endfunction
