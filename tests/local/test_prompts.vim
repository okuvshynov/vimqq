let s:suite = themis#suite('test_prompts.vim')
let s:assert = themis#helper('assert')

let s:path = expand('<sfile>:p:h:h:h') . '/prompts/'

function! s:suite.test_pick_basic()
    " Test basic prompt without context or index
    let message = {'sources': {}}
    let prompt = vimqq#prompts#pick(message)
    let expected = join(readfile(s:path . 'prompt.txt'), "\n")
    call s:assert.equals(prompt, expected)
endfunction

function! s:suite.test_pick_with_context()
    " Test prompt with context
    let message = {'sources': {'context': 'some context'}}
    let prompt = vimqq#prompts#pick(message)
    let expected = join(readfile(s:path . 'prompt_context.txt'), "\n")
    call s:assert.equals(prompt, expected)
endfunction

function! s:suite.test_pick_with_index()
    " Test prompt with index
    let message = {'sources': {'index': ['some index']}}
    let prompt = vimqq#prompts#pick(message)
    let expected = join(readfile(s:path . 'prompt_index.txt'), "\n")
    call s:assert.equals(prompt, expected)
endfunction

function! s:suite.test_pick_with_context_and_index()
    " Test prompt with both context and index
    let message = {'sources': {'context': 'some context', 'index': ['some index']}}
    let prompt = vimqq#prompts#pick(message)
    let expected = join(readfile(s:path . 'prompt_context_index.txt'), "\n")
    call s:assert.equals(prompt, expected)
endfunction

function! s:suite.test_pick_ui()
    " Test basic prompt with UI flag
    let message = {'sources': {}}
    let prompt = vimqq#prompts#pick(message, v:true)
    let expected = join(readfile(s:path . 'prompt_ui.txt'), "\n")
    call s:assert.equals(prompt, expected)
endfunction
