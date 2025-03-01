if exists('g:autoloaded_vimqq_api_llama_adapter')
    finish
endif

let g:autoloaded_vimqq_api_llama_adapter = 1

" TODO: how should we handle situations with > 1 content entry?
function! vimqq#api#llama_cpp_adapter#jinja(req)
    for message in a:req.messages
        if type(message.content) == type([])
            try
                let content = message.content[0]
                if content.type ==# 'text'
                    let message.content = message.content[0].text
                endif

                if content.type ==# 'tool_result'
                    let message.tool_call_id = content.tool_use_id
                    let message.content = content.content
                    let message.role = 'tool'
                    call vimqq#log#debug('tool reply ' . string(message))
                endif

                if content['type'] ==# 'tool_use'
                    let message.tool_calls = [{
                       \ 'id': content['id'],
                       \ 'type': 'function',
                       \ 'function': {
                       \    'name': content['name'],
                       \    'arguments': json_encode(content['input'])
                       \ }
                    \ }]
                    let message.content = ""
                endif
            catch
                call vimqq#log#error('llama_api: error adapting: ' . string(message.content))
            endtry
        endif
    endfor
endfunction

