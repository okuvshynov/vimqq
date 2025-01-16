let s:suite = themis#suite('Tool formatting tests')
let s:assert = themis#helper('assert')

function ToolDef()
    return {
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
endfunction

function ToolDefSonnet()
    return {
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
endfunction

function s:suite.test_to_claude()
    let s:expected = ToolDefSonnet()

    let s:observed = vimqq#tools#schema#to_claude(ToolDef())

    call s:assert.equals(s:expected, s:observed)
endfunction

