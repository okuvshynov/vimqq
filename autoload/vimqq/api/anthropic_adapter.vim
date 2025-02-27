if exists('g:autoloaded_vimqq_anthropic_adapter')
    finish
endif

let g:autoloaded_vimqq_anthropic_adapter = 1

" Translates tool definition schema to anthropic-compatible format
" Public for unit testing
function! vimqq#api#anthropic_adapter#tool_schema(schema)
    let fn = a:schema['function']
    let res = {
    \   'name': fn['name'],
    \   'description' : fn['description'],
    \   'input_schema' : fn['parameters']
    \} 
    return res
endfunction

function! vimqq#api#anthropic_adapter#adapt_tools(tools)
    let res = []
    for tool in a:tools
        call add(res, vimqq#api#anthropic_adapter#tool_schema(tool))
    endfor
    return res
endfunction


" receives messages in internal format
function! vimqq#api#anthropic_adapter#run(request)
    let tools = get(a:request, 'tools', [])
    let messages = a:request.messages
    
    let system_msg = v:null
    if messages[0].role ==# 'system'
        let system_msg = messages[0].content
        call remove(messages, 0)
    endif

    let req = {
    \   'messages' : messages,
    \   'model': a:request.model,
    \   'max_tokens' : get(a:request, 'max_tokens', 1024),
    \   'stream': get(a:request, 'stream', v:false),
    \   'tools': vimqq#api#anthropic_adapter#adapt_tools(tools)
    \}

    if system_msg isnot v:null
        let req['system'] = system_msg
    endif

    if has_key(a:request, 'thinking_tokens')
        let tokens = a:request['thinking_tokens']
        if has_key(a:request, 'on_sys_msg')
            call a:request.on_sys_msg(
                \ 'info',
                \ 'extended thinking with ' . tokens . ' token budget: ON')
        endif
        let req['thinking'] = {'type': 'enabled', 'budget_tokens': tokens}
    endif


    return req
endfunction
