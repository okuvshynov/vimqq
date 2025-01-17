let s:suite = themis#suite('tools')
let s:assert = themis#helper('assert')

function s:suite.test_get_files()
    let s:path = expand('<script>:p:h')
    let s:tool = vimqq#tools#get_files#new(s:path)

    let s:content = s:tool.run({'filepaths': ['tools_get_files.txt']})

    let s:expected = ['', 'tools_get_files.txt', 'Hello, world!']
    let s:expected = join(s:expected, '\n')
    call s:assert.equals(s:expected, s:content)
endfunction

function s:suite.test_get_files_not_found()
    let s:path = expand('<script>:p:h')
    let s:tool = vimqq#tools#get_files#new(s:path)

    let s:content = s:tool.run({'filepaths': ['non_existent_file.txt']})

    let s:expected = ['', 'non_existent_file.txt', 'ERROR: File not found.']
    let s:expected = join(s:expected, '\n')
    call s:assert.equals(s:expected, s:content)
endfunction
