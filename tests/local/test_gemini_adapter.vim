let s:suite = themis#suite('gemini_adapter')
let s:assert = themis#helper('assert')

function! s:suite.test_to_gemini() abort
    let s:tool_def = {
        \ 'function': {
        \     'name': 'test_tool',
        \     'description': 'test tool',
        \     'parameters': {
        \         'type': 'object',
        \         'properties': {
        \             'name': {
        \                 'type': 'string',
        \                 'description': 'name'
        \             }
        \         },
        \         'required': ['name']
        \     }
        \ }
    \ }

    let s:tool_def_gemini = {
        \ 'name': 'test_tool',
        \ 'description': 'test tool',
        \ 'parameters': {
        \     'type': 'object',
        \     'properties': {
        \         'name': {
        \             'type': 'string',
        \             'description': 'name'
        \         }
        \     },
        \     'required': ['name']
        \ }
    \ }
    
    call s:assert.equals(vimqq#api#gemini_adapter#tool_schema(s:tool_def), s:tool_def_gemini)
endfunction

function! s:suite.test_adapt_tools() abort
    let s:tool_def = {
        \ 'function': {
        \     'name': 'test_tool',
        \     'description': 'test tool',
        \     'parameters': {
        \         'type': 'object',
        \         'properties': {
        \             'name': {
        \                 'type': 'string',
        \                 'description': 'name'
        \             }
        \         },
        \         'required': ['name']
        \     }
        \ }
    \ }

    let s:expected = [
        \ {
        \     'name': 'test_tool',
        \     'description': 'test tool',
        \     'parameters': {
        \         'type': 'object',
        \         'properties': {
        \             'name': {
        \                 'type': 'string',
        \                 'description': 'name'
        \             }
        \         },
        \         'required': ['name']
        \     }
        \ }
    \ ]
    
    call s:assert.equals(vimqq#api#gemini_adapter#adapt_tools([s:tool_def]), s:expected)
endfunction