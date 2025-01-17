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
