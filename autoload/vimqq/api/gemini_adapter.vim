if exists('g:autoloaded_vimqq_gemini_adapter')
    finish
endif

let g:autoloaded_vimqq_gemini_adapter = 1

" Translates tool definition schema to gemini-compatible format
" Public for unit testing
function! vimqq#api#gemini_adapter#tool_schema(schema)
    let fn = a:schema['function']
    let res = {
    \   'name'         : fn['name'],
    \   'description'  : fn['description'],
    \   'parameters'   : fn['parameters']
    \ }
    return res
endfunction

let s:ROLE_MAP = {'user' : 'user', 'assistant' : 'model'}

function! vimqq#api#gemini_adapter#adapt_tools(tools)
    let res = []
    for tool in a:tools
        call add(res, vimqq#api#gemini_adapter#tool_schema(tool))
    endfor
    return res
endfunction

" Translates internal message format to Gemini API format
function! vimqq#api#gemini_adapter#run(request)
    let tools = get(a:request, 'tools', [])
    let messages = a:request.messages
    
    " Handle system message
    let system_prompt = v:null
    if messages[0].role ==# 'system'
        let system_prompt = messages[0].content
        call remove(messages, 0)
    endif
    
    let req = {
    \   'contents'     : [],
    \   'model'        : a:request.model,
    \   'generationConfig' : {
    \       'maxOutputTokens' : get(a:request, 'max_tokens', 1024),
    \   },
    \ }
    
    for message in messages
        let entry = {'role' : s:ROLE_MAP[message.role], 'parts': []}
        for content in message.content
            if content['type'] ==# 'text'
                call add(entry.parts, {'text' : content.text})
                continue
            endif

            if content['type'] ==# 'tool_use'
                let fn_call = {'functionCall' : {
                    \ 'name': content['name'],
                    \ 'args': content['input']
                \ }}
                call add(entry.parts, fn_call)
                continue
            endif

            if content['type'] ==# 'tool_result'
                let fn_result = { 'functionResponse' : {
                    \ 'name' : 'tool_name_tbd',
                    \ 'response' : { 'result' : content['content']}
                \ }}
                call add(entry.parts, fn_result)
                continue
            endif
        endfor
        call add(req.contents, entry)
    endfor
    
    " Add system prompt if present
    if system_prompt isnot v:null
        let req['system_instruction'] = {'parts' : [{'text' : system_prompt}]}
    endif

    if has_key(a:request, 'tools')
        let req['tools'] = [{'functionDeclarations' : vimqq#api#gemini_adapter#adapt_tools(a:request['tools'])}]
    endif
    
    return req
endfunction
