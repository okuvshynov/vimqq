let s:suite = themis#suite('test_tools_schema.vim')
let s:assert = themis#helper('assert')

let s:tool_def = {
        \ 'type': 'function',
        \ 'function': {
            \ 'name': 'get_files',
            \ 'description': 'Gets content of one or more files.',
            \ 'parameters': {
                \ 'type': 'object',
                \ 'properties': {
                    \ 'filepaths': {
                        \ 'type': 'array',
                        \ 'items': {
                            \ 'type': 'string'
                        \ },
                        \ 'description': 'A list of file paths to get the content.'
                    \ }
                \ },
                \ 'required': ['filepaths']
            \ }
        \ }
    \ }

let s:tool_def_claude = {
        \ 'name': 'get_files',
        \ 'description': 'Gets content of one or more files.',
        \ 'input_schema': {
            \ 'type': 'object',
            \ 'properties': {
                \ 'filepaths': {
                    \ 'type': 'array',
                    \ 'items': {
                        \ 'type': 'string'
                    \ },
                    \ 'description': 'A list of file paths to get the content.'
                \ }
            \ },
            \ 'required': ['filepaths']
        \ }
    \ }

function s:suite.test_to_claude()
    let s:observed = vimqq#api#anthropic_api#to_claude(s:tool_def)

    call s:assert.equals(s:observed, s:tool_def_claude)
endfunction

