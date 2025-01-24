let s:suite = themis#suite('fmt one')
let s:assert = themis#helper('assert')

function! s:suite.test_fmt_user_message()
    " Test formatting a user message without UI
    let msg = {
        \ 'timestamp': localtime(),
        \ 'role': 'user',
        \ 'bot_name': 'test_bot',
        \ 'sources': {'text': 'Hello bot'}
    \}

    let result = vimqq#fmt#for_wire(msg)
    call s:assert.equals(result.content[0].text, 'Hello bot')
    call s:assert.false(has_key(result, 'author'))

    " Test formatting a user message with UI
    let result_ui = vimqq#fmt_ui#for_ui(msg)
    call s:assert.equals(result_ui.text, 'Hello bot')
    call s:assert.equals(result_ui.author, 'You: @test_bot ')
endfunction

function! s:suite.test_fmt_assistant_message()
    " Test formatting an assistant message without UI
    let msg = {
        \ 'timestamp': localtime(),
        \ 'role': 'assistant',
        \ 'bot_name': 'test_bot',
        \ 'sources': {'text': 'Hello user'}
    \}

    let result = vimqq#fmt#for_wire(msg)
    call s:assert.equals(result.content[0].text, 'Hello user')
    call s:assert.false(has_key(result, 'author'))

    " Test formatting an assistant message with UI
    let result_ui = vimqq#fmt_ui#for_ui(msg)
    call s:assert.equals(result_ui.text, 'Hello user')
    call s:assert.equals(result_ui.author, 'test_bot: ')
endfunction

function! s:suite.test_fmt_tool_result()
    " Test formatting a tool result message with short output
    let msg = {
        \ 'timestamp': localtime(),
        \ 'role': 'assistant',
        \ 'bot_name': 'test_bot',
        \ 'content': [{'type': 'tool_result', 'content': 'tool_output'}]
    \}

    let result = vimqq#fmt#for_wire(msg)
    call s:assert.equals(result.content[0].type, 'tool_result')

    " Test formatting a tool result message with UI (short output)
    let result_ui = vimqq#fmt_ui#for_ui(msg)
    call s:assert.equals(result_ui.text, "\n\n[tool_call_result]\ntool_output\n")
    call s:assert.equals(result_ui.author, 'tool: @test_bot ')

    " Test formatting a tool result message with long output that needs folding
    let long_output = repeat('x', 500)
    let msg_long = {
        \ 'timestamp': localtime(),
        \ 'role': 'assistant',
        \ 'bot_name': 'test_bot',
        \ 'content': [{'type': 'tool_result', 'content': long_output}]
    \}

    " Test formatting a tool result message with UI (long output)
    let result_ui_long = vimqq#fmt_ui#for_ui(msg_long)
    call s:assert.equals(result_ui_long.text, "\n\n[tool_call_result]\n{{{\n" . long_output . "\n}}}\n")
    call s:assert.equals(result_ui_long.author, 'tool: @test_bot ')
endfunction

function! s:suite.test_fmt_tool_use()
    " Test formatting a message with tool use
    let msg = {
        \ 'timestamp': localtime(),
        \ 'role': 'assistant',
        \ 'bot_name': 'test_bot',
        \ 'sources': {'text': 'Using tool'},
        \ 'tool_use': {
            \ 'id': '123',
            \ 'name': 'edit_file',
            \ 'input': {'filepath': 'hello.txt'}
        \ }
    \}

    let result = vimqq#fmt#for_wire(msg)
    call s:assert.equals(result.content[0].type, 'text')
    call s:assert.match(result.content[0].text, 'Using tool')
    call s:assert.equals(result.content[1].type, 'tool_use')
    call s:assert.equals(result.content[1].name, 'edit_file')
    call s:assert.equals(result.content[1].input, {'filepath': 'hello.txt'})

    " Test formatting a message with tool use with UI
    let result_ui = vimqq#fmt_ui#for_ui(msg)
    call s:assert.match(result_ui.text, 'Using tool')
    call s:assert.match(result_ui.text, '\[tool_call: edit_file(''hello.txt'')\]')
endfunction
