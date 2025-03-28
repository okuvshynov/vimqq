if exists('g:autoloaded_vimqq_gemini_builder')
    finish
endif

let g:autoloaded_vimqq_gemini_builder = 1

function! vimqq#api#gemini_builder#streaming(params) abort
    let builder = vimqq#msg_builder#new(a:params).set_role('assistant')

    " Functions to handle streaming response from Gemini API
    
    function! builder.content_block_start(index, content_block) dict
        " Initialize a new content block when streaming begins
        call assert_true(
            \ a:index == len(self.msg.content),
            \ 'trying to add content at index = ' . a:index
            \ . ' to message with content size = ' . len(self.msg.content)
        \ )
        call add(self.msg.content, deepcopy(a:content_block))
    endfunction

    function! builder.content_block_delta(index, delta) dict
        " Process content delta updates
        call assert_true(
            \ a:index < len(self.msg.content),
            \ 'trying to add content at index = ' . a:index
            \ . ' to message with content size = ' . len(self.msg.content)
        \ )
        
        " TODO: Implement delta handling based on Gemini's response format
        " The following is a placeholder based on Anthropic's format
        if a:delta['type'] ==# 'text_delta'
            call self.text_delta(a:index, a:delta.text)
        endif
        if a:delta['type'] ==# 'tool_delta'
            call self.tool_delta(a:index, a:delta.tool)
        endif
        " Add other delta types as needed for Gemini
    endfunction

    function! builder.text_delta(index, delta) dict
        " Handle text delta updates
        let content = self.msg.content[a:index]
        call assert_true(
            \ type(a:delta) == type(""),
            \ "delta must be a string, found type " . type(a:delta)
        \ )
        call assert_true(
            \ content.type ==# 'text', 
            \ "trying to append text delta to " . content.type
        \ )
        if !has_key(content, 'text')
            let content['text'] = a:delta
        else
            let content['text'] .= a:delta
        endif
        call self.on_chunk(self.params, a:delta)
    endfunction

    function! builder.tool_delta(index, delta) dict
        " Handle tool usage deltas
        " TODO: Implement based on Gemini's tool response format
        let content = self.msg.content[a:index]
        call assert_true(
            \ type(a:delta) == type(""),
            \ "delta must be a string, found type " . type(a:delta)
        \ )
        call assert_true(
            \ content.type ==# 'tool_use', 
            \ "trying to append tool delta to " . content.type
        \ )

        " Implementation will depend on how Gemini streams tool usage
    endfunction

    " Called when an individual content block is complete
    function! builder.content_block_stop(index) dict
        call assert_true(
            \ a:index < len(self.msg.content),
            \ 'trying to finalize content at index = ' . a:index
            \ . ' for message with content size = ' . len(self.msg.content)
        \ )
        let content = self.msg.content[a:index]

        " Process the completed content block
        " TODO: Implement based on Gemini's response format
    endfunction

    function! builder.message_stop() dict
        " Called when the entire message is complete
        call self.on_complete(v:null, self.params, self.msg)
    endfunction

    return builder
endfunction

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
        
        " Transform Gemini response to internal message format
        " Format will depend on the Gemini API response structure
        
        " Placeholder implementation
        " self.msg.content = parsed.candidates[0].content...
        
        " Process chunks
        for content in self.msg.content
            if get(content, 'type', '') ==# 'text'
                call self.on_chunk(self.params, content['text'])
            endif
        endfor
        call self.on_complete(v:null, self.params, self.msg)
    endfunction

    return builder
endfunction