let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../libtest.vim"
execute "source " . s:lib

function! ToolDef()
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

function! ToolDefSonnet()
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

let s:expected = ToolDefSonnet()

let s:observed = vimqq#tools#schema#to_claude(ToolDef())

if DeepDictCompare(s:expected, s:observed) == 1
    cquit 1
else
    cquit 0
endif
