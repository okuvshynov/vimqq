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

function! Test_to_claude()
    let s:expected = ToolDefSonnet()

    let s:observed = vimqq#tools#schema#to_claude(ToolDef())

    call ASSERT_EQ_DICT(s:expected, s:observed)
endfunction

call RunAllTests()
