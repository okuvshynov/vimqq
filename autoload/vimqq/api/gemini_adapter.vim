if exists('g:autoloaded_vimqq_gemini_adapter')
    finish
endif

let g:autoloaded_vimqq_gemini_adapter = 1

" Translates tool definition schema to gemini-compatible format
" Public for unit testing
function! vimqq#api#gemini_adapter#tool_schema(schema)
    " TODO: Implement proper schema translation for Gemini
    " This will depend on how Gemini expects tool definitions
    let fn = a:schema['function']
    let res = {
    \   'name'         : fn['name'],
    \   'description'  : fn['description'],
    \   'parameters'   : fn['parameters']
    \ }
    return res
endfunction

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
    
    " TODO: Implement proper format for Gemini API
    " This is a placeholder structure that will need to be adjusted 
    " based on Gemini API documentation
    let req = {
    \   'contents'     : [],  " Will be populated with converted messages
    \   'model'        : a:request.model,
    \   'generationConfig' : {
    \       'maxOutputTokens' : get(a:request, 'max_tokens', 1024),
    \   },
    \   'stream'       : get(a:request, 'stream', v:false),
    \   'tools'        : vimqq#api#gemini_adapter#adapt_tools(tools)
    \ }
    
    " Process and convert messages to Gemini format
    " TODO: Implement proper message conversion for Gemini
    
    " Add system prompt if present
    if system_prompt isnot v:null
        " TODO: Adjust based on how Gemini handles system prompts
        " This might be in a different format than Anthropic's API
    endif
    
    " Add extended thinking capability if requested
    if has_key(a:request, 'thinking_tokens')
        let tokens = a:request['thinking_tokens']
        if has_key(a:request, 'on_sys_msg')
            call a:request.on_sys_msg(
                \ 'info',
                \ 'extended thinking with ' . tokens . ' token budget: ON')
        endif
        " TODO: Implement thinking tokens feature for Gemini if available
        " or closest equivalent
    endif
    
    return req
endfunction