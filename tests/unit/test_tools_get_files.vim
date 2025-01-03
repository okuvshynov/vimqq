let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../libtest.vim"
execute "source " . s:lib

function! Test_get_files()
    let s:tool = vimqq#tools#get_files#new(s:path)

    let s:content = s:tool.run({'filepaths': ['tools_get_files.txt']})

    let s:expected = ['', 'tools_get_files.txt', 'Hello, world!']
    let s:expected = join(s:expected, '\n')
    call ASSERT_EQ(s:expected, s:content)
endfunction

call RunAllTests()
