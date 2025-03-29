if exists('g:autoloaded_vimqq_gemini_builder')
    finish
endif

let g:autoloaded_vimqq_gemini_builder = 1

function! vimqq#api#gemini_builder#plain(params) abort
    " Builder for non-streaming responses
    let builder = vimqq#msg_builder#new(a:params).set_role('assistant')
    
    let builder.parts = []

    function! builder.part(part) dict
        " Collect parts of the response
        call add(self.parts, a:part)
    endfunction

    function! builder.append_text(text) dict
        if len(self.msg.content) == 0
            let self.msg.content = [{'type': 'text', 'text': ''}]
        endif
        let self.msg.content[0].text = self.msg.content[0].text . a:text
    endfunction

    function! builder.close() dict
        let parsed = json_decode(join(self.parts, "\n"))
        call vimqq#log#debug(string(parsed))

        let candidate = get(get(parsed, 'candidates', []), 0, {})
        let parts     = get(get(candidate, 'content', {}), 'parts', []) 

        for part in parts
            if has_key(part, 'text')
                call self.append_text(part.text)
                call self.on_chunk(self.params, part.text)
            endif

            if has_key(part, 'functionCall')
                let content = {
                    \ 'type' : 'tool_use',
                    \ 'input': part.functionCall.args,
                    \ 'id'   : 0,
                    \ 'name' : part.functionCall.name
                \ }
                call add(self.msg.content, content)
            endif
        endfor

        call self.on_complete(v:null, self.params, self.msg)
    endfunction

    return builder
endfunction
