let g:vqq_llama_servers[0]['do_autowarm'] = v:true

let s:path = expand('<sfile>:p:h')
let s:lib = s:path . "/../../libtest.vim"
execute "source " . s:lib

" TODO: This test is not testing much...
function! Test_warmup_open()
    :Q @mock hello
    :sleep 500m

    let content = getline(1, '$')
    let expected = readfile(s:path . '/' . 'query.out')
    call ASSERT_EQ_CHATS(content, expected)
endfunction

call RunAllTests()
