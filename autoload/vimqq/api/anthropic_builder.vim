if exists('g:autoloaded_vimqq_anthropic_builder')
    finish
endif

let g:autoloaded_vimqq_anthropic_builder = 1

function! vimqq#api#anthropic_builder#streaming(params) abort
    let builder = vimqq#msg_builder#new(a:params).set_role('assistant')

    function! builder.content_block_start(index, content_block) dict
        call vimqq#log#debug(string(a:content_block))
        call assert_true(
            \ a:index == len(self.msg.content),
            \ 'trying to add content at index = ' . a:index
            \ . ' to message with content size = ' . len(self.msg.content)
        \ )
        call add(self.msg.content, deepcopy(a:content_block))
    endfunction

    function! builder.content_block_delta(index, delta) dict
        call assert_true(
            \ a:index < len(self.msg.content),
            \ 'trying to add content at index = ' . a:index
            \ . ' to message with content size = ' . len(self.msg.content)
        \ )
        if a:delta['type'] ==# 'text_delta'
            call self.text_delta(a:index, a:delta.text)
        endif
        if a:delta['type'] ==# 'input_json_delta'
            call self.partial_json_delta(a:index, a:delta.partial_json)
        endif
        if a:delta['type'] ==# 'thinking_delta'
            call self.thinking_delta(a:index, a:delta.thinking)
        endif
    endfunction

    function! builder.text_delta(index, delta) dict
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

    function! builder.partial_json_delta(index, delta) dict
        let content = self.msg.content[a:index]
        call assert_true(
            \ type(a:delta) == type(""),
            \ "delta must be a string, found type " . type(a:delta)
        \ )
        call assert_true(
            \ content.type ==# 'tool_use', 
            \ "trying to append partial json to " . content.type
        \ )

        if !has_key(content, 'input_part')
            let content['input_part'] = a:delta
        else
            let content['input_part'] .= a:delta
        endif
    endfunction

    function! builder.thinking_delta(index, delta) dict
        let content = self.msg.content[a:index]
        call assert_true(
            \ type(a:delta) == type(""),
            \ "delta must be a string, found type " . type(a:delta)
        \ )
        call assert_true(
            \ content.type ==# 'thinking', 
            \ "trying to append thinking delta to " . content.type
        \ )

        if !has_key(content, 'thinking')
            let content['thinking'] = a:delta
        else
            let content['thinking'] .= a:delta
        endif
        call self.on_thinking(self.params, a:delta)
    endfunction

    " individual piece of content is complete
    function! builder.content_block_stop(index) dict
        call assert_true(
            \ a:index < len(self.msg.content),
            \ 'trying to finalize content at index = ' . a:index
            \ . ' for message with content size = ' . len(self.msg.content)
        \ )
        let content = self.msg.content[a:index]

        if content.type ==# 'tool_use'
            if has_key(content, 'input_part')
                let content.input = json_decode(content.input_part)
                unlet content.input_part
            endif
        endif

        if content.type ==# 'redacted_thinking'
            " TODO: do we need to do anything here?
            " Not for anthropic
        endif
    endfunction

    function! builder.message_stop() dict
        call self.on_complete(v:null, self.params, self.msg)
    endfunction

    return builder
endfunction

function! vimqq#api#anthropic_builder#plain(params) abort
    let builder = vimqq#msg_builder#new(a:params).set_role('assistant')
    
    let builder.parts = []

    function! builder.part(part) dict
        call add(self.parts, a:part)
    endfunction

    function! builder.close() dict
        let parsed = json_decode(join(self.parts, "\n"))
        let self.msg.content = parsed.content
        for content in self.msg.content
            if get(content, 'type', '') ==# 'text'
                call self.on_chunk(self.params, content['text'])
            endif
        endfor
        call self.on_complete(v:null, self.params, self.msg)
    endfunction

    return builder
endfunction


