if exists('g:autoloaded_vimqq_llama_cpp_builder')
    finish
endif

let g:autoloaded_vimqq_llama_cpp_builder = 1

" No tool calling + streaming at the moment
function! vimqq#api#llama_cpp_builder#streaming(params) abort
    let builder = vimqq#msg_builder#new(a:params).set_role('assistant')

    function! builder.append_text(text) dict
        if len(self.msg.content) == 0
            let self.msg.content = [{'type': 'text', 'text': ''}]
        endif
        let self.msg.content[0].text = self.msg.content[0].text . a:text
    endfunction

    function! builder.handle_usage(usage) dict
        let usage = {}
        let usage.input_tokens = get(a:usage, 'prompt_tokens', 0)
        let usage.output_tokens = get(a:usage, 'completion_tokens', 0)
        call self.on_usage(usage)
    endfunction

    function! builder.delta(response) dict
        if has_key(a:response.choices[0].delta, 'content')
            let chunk = a:response.choices[0].delta.content
            call self.append_text(chunk)
            call self.on_chunk(self.params, chunk)
        endif
        if has_key(a:response, "usage")
            call self.handle_usage(a:response.usage)
        endif
        if has_key(a:response, "timings")
            let tps = get(a:response.timings, "predicted_per_second", "n/a")
            let tps = printf('server: generation = %.3f tok/s', tps)
            " With warmup tps for prompt processing is misleading
            " Let's just track TTFT instead.
            call self.on_sys_msg('info', tps)
        endif
    endfunction

    function! builder.message_stop() dict
        call self.on_complete(v:null, self.params, self.msg)
    endfunction

    return builder
endfunction

function! vimqq#api#llama_cpp_builder#plain(params) abort
    let builder = vimqq#msg_builder#new(a:params).set_role('assistant')

    let builder.parts = []

    function! builder.handle_usage(usage) dict
        let usage = {}
        let usage.input_tokens = get(a:usage, 'prompt_tokens', 0)
        let usage.output_tokens = get(a:usage, 'completion_tokens', 0)
        call self.on_usage(usage)
    endfunction

    function! builder.append_text(text) dict
        if len(self.msg.content) == 0
            let self.msg.content = [{'type': 'text', 'text': ''}]
        endif
        let self.msg.content[0].text = self.msg.content[0].text . a:text
    endfunction

    function! builder.part(part) dict
        call add(self.parts, a:part)
    endfunction

    function! builder.close() dict
        let json_text = join(self.parts, "\n")
        try
            let parsed = json_decode(json_text)
            let message = parsed.choices[0].message
        catch
            call self.on_complete('error', self.params, self.msg)
            return
        endtry
        if has_key(parsed, 'usage')
            call self.handle_usage(parsed.usage)
        endif
        if has_key(message, 'content')
            if message['content'] isnot v:null
                call self.append_text(message.content)
                call self.on_chunk(self.params, message.content)
            endif
        endif
        if has_key(message, 'tool_calls')
            if message.tool_calls isnot v:null
                for tool_call in message['tool_calls']
                    let function_call = tool_call['function']
                    let content = {
                        \ 'type' : 'tool_use',
                        \ 'input': json_decode(function_call.arguments),
                        \ 'id'   : tool_call.id,
                        \ 'name' : function_call.name
                    \ }
                    call add(self.msg.content, content)
                endfor
            endif
        endif
        call self.on_complete(v:null, self.params, self.msg)
    endfunction

    return builder
endfunction

