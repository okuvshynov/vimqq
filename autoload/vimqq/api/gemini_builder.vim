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

    function! builder.close() dict
        " Process the complete response
        " TODO: Adjust parsing based on Gemini's response format
        let parsed = json_decode(join(self.parts, "\n"))

        let text = parsed.candidates[0].content.parts[0].text
        call vimqq#log#debug(text)

        let self.msg.content = [{'type': 'text', 'text' : text}]

        call self.on_chunk(self.params, text)
        call self.on_complete(v:null, self.params, self.msg)
    endfunction

    return builder
endfunction
