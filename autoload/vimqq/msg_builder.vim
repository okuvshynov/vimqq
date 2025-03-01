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
    let builder.on_sys_msg  = get(a:params, 'on_sys_msg' , {l, m    -> 0})
    let builder.on_chunk    = get(a:params, 'on_chunk'   , {p, c    -> 0})
    let builder.on_thinking = get(a:params, 'on_thinking', {p, t    -> 0})
    let builder.on_complete = get(a:params, 'on_complete', {e, p, m -> 0})

    let builder.params = a:params
    let builder.params._builder = builder

    let builder.msg = {}

    " types of content:
    "  - text [user, assistant]
    "  - tool_use [assistant]
    "  - tool_result [user]
    "  - thinking [assistant]
    "  - redacted_thinking [assistant]
    let builder.msg.content = []
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

    function! builder.set_bot_name(bot_name) dict
        call assert_true(
            \ type(a:bot_name) == type(""),
            \ "bot_name must be a string, found type " . type(a:bot_name)
        \ )
        let self.msg.bot_name = a:bot_name
        return self
    endfunction

    return builder
endfunction

function! vimqq#msg_builder#user() abort
    let builder = vimqq#msg_builder#new({}).set_role('user')

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

    function! builder._set_src_text(text) dict
        call assert_true(
            \ type(a:text) == type(""),
            \ "text must be a string, found type " . type(a:text)
        \ )
        let self.msg.sources.text = a:text
        return self
    endfunction

    " this is currently 'visual selection'
    function! builder._set_src_context(context) dict
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

    function! builder._set_src_index(index) dict
        call assert_true(
            \ type(a:index) == type(""),
            \ "index must be a string, found type " . type(a:index)
        \ )
        let self.msg.sources.index = a:index
        return self
    endfunction

    function! builder.set_sources(question, context, use_index) dict
        call self._set_src_text(a:question)
        call self._set_src_context(a:context)
        if a:use_index
           call self._set_src_index(vimqq#lucas#load())
        endif
        let prompt = vimqq#prompts#pick(self.msg, v:false)
        let text = vimqq#prompts#apply(self.msg, prompt)
        let content = {'type': 'text', 'text': text}
        call add(self.msg.content, content)
        return self
    endfunction

    return builder
endfunction

function! vimqq#msg_builder#local() abort
    let builder = vimqq#msg_builder#new({}).set_role('local')

    function! builder.set_local(level, text) dict
        let content = {'type': 'text', 'text' : a:text, 'level': a:level}
        call add(self.msg.content, content)
        return self
    endfunction

    return builder
endfunction

function! vimqq#msg_builder#tool() abort
    let builder = vimqq#msg_builder#new({}).set_role('user')

    function! builder.tool_result(id, result) dict
        let content = {
        \   'type' : 'tool_result',
        \   'tool_use_id' : a:id,
        \   'content' : a:result
        \ }
        call add(self.msg.content, content)
        return self
    endfunction

    return builder
endfunction
