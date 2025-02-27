if exists('g:autoloaded_vimqq_msg_builder')
    finish
endif

let g:autoloaded_vimqq_msg_builder = 1

" what kind of callbacks we expect? All are optional
" - on_sys_msg
" - on_chunk
" - on_complete
" - on_thinking
function! vimqq#msg_builder#new(params) abort
    let builder = {}
    " sys message to show in chat
    let builder.on_sys_msg  = get(a:params, 'on_sys_msg' , {l, m -> 0})

    " this is text delta
    let builder.on_chunk    = get(a:params, 'on_chunk'   , {p, c -> 0})

    " this is thinking process. need to do by chunk
    let builder.on_thinking = get(a:params, 'on_thinking', {p, t -> 0})

    let builder.on_complete = get(a:params, 'on_complete', {e, p -> 0})

    let builder.params = a:params

    let builder.params._builder = builder

    let builder.msg = {}

    " To gradually migrate various places in the codebase
    " we create a flag to indicate this comes from builder
    let builder.msg.v2 = 1

    " types of content:
    "  - text [user, assistant]
    "  - tool_use [assistant]
    "  - tool_result [user]
    "  - thinking [assistant]
    "  - redacted_thinking [assistant]
    let builder.msg.content = []
    " sources are relevant for user-initiated messages only
    " assistant replies and tool interations are not going to
    " have sources.
    " sources can have following entries
    "  - text    - user question as typed
    "  - context - usually code selection
    "  - index   - repository summary
    "  sources are used to differently render such message 
    "  in UI and send over the wire.
    "  so for user messages we will NOT have normal content: text
    "  and will create it on the fly.
    let builder.msg.sources = {}

    let builder.msg.timestamp = localtime()

    function! builder.set_role(role) dict
        let roles = ['user', 'assistant', 'local']
        call assert_true(
            \ index(roles, a:role) >= 0,
            \ "role must be one of " . string(roles) . ", found " . a:role
        \ )
        let self.msg.role = a:role
        return self
    endfunction

    function! builder.set_src_text(text) dict
        call assert_true(
            \ type(a:text) == type(""),
            \ "text must be a string, found type " . type(a:text)
        \ )
        let self.msg.sources.text = a:text
        return self
    endfunction

    function! builder.set_bot_name(bot_name) dict
        call assert_true(
            \ type(a:bot_name) == type(""),
            \ "bot_name must be a string, found type " . type(a:bot_name)
        \ )
        let self.msg.bot_name = a:bot_name
        return self
    endfunction

    " this is currently 'visual selection'
    function! builder.set_src_context(context) dict
        if a:context is v:null
            return self
        endif
        call assert_true(
            \ type(a:context) == type(""),
            \ "context must be a string, found type " . type(a:context)
        \ )
        let self.msg.sources.context = a:context
        return self
    endfunction

    function! builder.set_src_index(index) dict
        call assert_true(
            \ type(a:index) == type(""),
            \ "index must be a string, found type " . type(a:index)
        \ )
        let self.msg.sources.index = a:index
        return self
    endfunction

    function! builder.set_sources(question, context, use_index)
        call self.set_src_text(a:question)
        call self.set_src_context(a:context)
        if a:use_index
           call self.set_src_index(vimqq#lucas#load())
        endif
        let prompt = vimqq#prompts#pick(self.msg, v:false)
        let text = vimqq#prompts#apply(self.msg, prompt)
        call self.add_content({'type': 'text', 'text': text})
        return self
    endfunction

    " """""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " Streaming-like API.
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

    " """"""""""""""""""""""""""""""""""""""""""""""""""""
    " non-streaming API built on top of streaming API
    function! builder.tool_result(content) dict
        call add(self.msg.content, a:content)
    endfunction

    function! builder.add_content(content) dict
        call add(self.msg.content, a:content)
    endfunction

    return builder
endfunction
