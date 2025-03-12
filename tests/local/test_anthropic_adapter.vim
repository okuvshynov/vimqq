let s:suite = themis#suite('test_anthropic_adapter.vim')
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
    let s:observed = vimqq#api#anthropic_adapter#tool_schema(s:tool_def)

    call s:assert.equals(s:observed, s:tool_def_claude)
endfunction

function s:suite.test_adapt_tools()
    let tools = [s:tool_def]
    let expected = [s:tool_def_claude]
    
    let observed = vimqq#api#anthropic_adapter#adapt_tools(tools)
    
    call s:assert.equals(observed, expected)
endfunction

function s:suite.test_adapt_multiple_tools()
    let tool_def2 = {
        \ 'type': 'function',
        \ 'function': {
            \ 'name': 'edit_file',
            \ 'description': 'Edits a file by replacing text.',
            \ 'parameters': {
                \ 'type': 'object',
                \ 'properties': {
                    \ 'filepath': {
                        \ 'type': 'string',
                        \ 'description': 'Path to the file to edit.'
                    \ },
                    \ 'needle': {
                        \ 'type': 'string',
                        \ 'description': 'Text to replace.'
                    \ },
                    \ 'replacement': {
                        \ 'type': 'string',
                        \ 'description': 'Replacement text.'
                    \ }
                \ },
                \ 'required': ['filepath', 'needle', 'replacement']
            \ }
        \ }
    \ }
    
    let tool_def2_claude = {
        \ 'name': 'edit_file',
        \ 'description': 'Edits a file by replacing text.',
        \ 'input_schema': {
            \ 'type': 'object',
            \ 'properties': {
                \ 'filepath': {
                    \ 'type': 'string',
                    \ 'description': 'Path to the file to edit.'
                \ },
                \ 'needle': {
                    \ 'type': 'string',
                    \ 'description': 'Text to replace.'
                \ },
                \ 'replacement': {
                    \ 'type': 'string',
                    \ 'description': 'Replacement text.'
                \ }
            \ },
            \ 'required': ['filepath', 'needle', 'replacement']
        \ }
    \ }
    
    let tools = [s:tool_def, tool_def2]
    let expected = [s:tool_def_claude, tool_def2_claude]
    
    let observed = vimqq#api#anthropic_adapter#adapt_tools(tools)
    
    call s:assert.equals(observed, expected)
endfunction

function s:suite.test_run_with_system_message()
    let request = {
        \ 'model': 'claude-3-opus-20240229',
        \ 'messages': [
            \ {'role': 'system', 'content': 'You are a helpful assistant'},
            \ {'role': 'user', 'content': 'Hello'}
        \ ],
        \ 'max_tokens': 2048,
        \ 'stream': v:true
    \ }
    
    let expected = {
        \ 'model': 'claude-3-opus-20240229',
        \ 'messages': [
            \ {'role': 'user', 'content': 'Hello'}
        \ ],
        \ 'max_tokens': 2048,
        \ 'stream': v:true,
        \ 'system': 'You are a helpful assistant',
        \ 'tools': []
    \ }
    
    let observed = vimqq#api#anthropic_adapter#run(request)
    
    call s:assert.equals(observed, expected)
endfunction

function s:suite.test_run_with_tools()
    let request = {
        \ 'model': 'claude-3-opus-20240229',
        \ 'messages': [
            \ {'role': 'user', 'content': 'Get the contents of test file'}
        \ ],
        \ 'tools': [s:tool_def],
        \ 'max_tokens': 1024,
        \ 'stream': v:false
    \ }
    
    let expected = {
        \ 'model': 'claude-3-opus-20240229',
        \ 'messages': [
            \ {'role': 'user', 'content': 'Get the contents of test file'}
        \ ],
        \ 'max_tokens': 1024,
        \ 'stream': v:false,
        \ 'tools': [s:tool_def_claude]
    \ }
    
    let observed = vimqq#api#anthropic_adapter#run(request)
    
    call s:assert.equals(observed, expected)
endfunction

function s:suite.test_run_with_thinking_tokens()
    let on_sys_msg_called = 0
    let on_sys_msg_level = ''
    let on_sys_msg_message = ''
    
    function! TestOnSysMsg(level, message) closure
        let on_sys_msg_called = 1
        let on_sys_msg_level = a:level
        let on_sys_msg_message = a:message
    endfunction
    
    let request = {
        \ 'model': 'claude-3-opus-20240229',
        \ 'messages': [
            \ {'role': 'user', 'content': 'Complex question requiring thinking'}
        \ ],
        \ 'thinking_tokens': 500,
        \ 'on_sys_msg': function('TestOnSysMsg'),
        \ 'max_tokens': 1024,
        \ 'stream': v:false
    \ }
    
    let expected = {
        \ 'model': 'claude-3-opus-20240229',
        \ 'messages': [
            \ {'role': 'user', 'content': 'Complex question requiring thinking'}
        \ ],
        \ 'max_tokens': 1024,
        \ 'stream': v:false,
        \ 'thinking': {'type': 'enabled', 'budget_tokens': 500},
        \ 'tools': []
    \ }
    
    let observed = vimqq#api#anthropic_adapter#run(request)
    
    call s:assert.equals(observed, expected)
    call s:assert.equals(on_sys_msg_called, 1)
    call s:assert.equals(on_sys_msg_level, 'info')
    call s:assert.equals(on_sys_msg_message, 'extended thinking with 500 token budget: ON')
endfunction

