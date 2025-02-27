if exists('g:autoloaded_vimqq_tools_toolset_module')
    finish
endif

let g:autoloaded_vimqq_tools_toolset_module = 1

function! s:find_lucas_root()
    let current_dir = expand('%:p:h')
    let prev_dir = ''

    while current_dir !=# prev_dir
        " Check if lucas.idx file exists in current dir
        let file_path = current_dir . '/lucas.idx'
        if filereadable(file_path)
            return current_dir
        endif

        let prev_dir = current_dir
        let current_dir = fnamemodify(current_dir, ':h')
    endwhile
    return v:null
endfunction

function! vimqq#tools#toolset#new()
    let res = {}

    let root = s:find_lucas_root()

    let res.tools = [
        \ vimqq#tools#get_files#new(root),
        \ vimqq#tools#edit_file#new(root),
        \ vimqq#tools#create_file#new(root),
        \ vimqq#tools#run_cmd#new(root)
    \ ]

    function! res.def() dict
        let res = []
        for tool in self.tools
            call add(res, tool.schema())
        endfor
        return res
    endfunction

    function! res.run_async(tool_call, callback) dict
        call vimqq#log#debug('tool call: ' . string(a:tool_call))
        for tool in self.tools
            if tool.name() ==# a:tool_call['name']
                call tool.run_async(a:tool_call['input'], a:callback)
                return
            endif
        endfor
        call vimqq#log#error('Unknown tool: ' . a:tool_call['name'])
        call a:callback(v:null)
    endfunction

    " checks all tool calls in the message content
    " runs each sequentiall (to avoid race conditions - 
    " tools have shared access to external resources)
    " once done, calls callback with constructed message
    " returns v:true if any tool call was enqueued
    function! res.run(msg, reply_builder, callback)
        let tool_uses = 0
        let completed = 0
        let builder = a:reply_builder
        let OnComplete = a:callback

        for content in a:msg.content
            if content['type'] ==# 'tool_use'
                let tool_uses = tool_uses + 1
            endif
        endfor

        let content = a:msg.content

        function! s:SaveResult(result, idx) closure
            call builder.tool_result(content[a:idx]['id'], a:result)
            let completed = completed + 1

            if completed == tool_uses
                call OnComplete(builder.msg)
            else
                call s:RunIfTool(a:idx + 1)
            endif
        endfunction

        " chaining of async tool calls
        function! s:RunIfTool(idx) closure
            if a:idx >= len(content)
                return
            endif
            if content[a:idx]['type'] ==# 'tool_use'
                call self.run_async(
                \   content[a:idx],
                \   {r -> s:SaveResult(r, a:idx)}
                \ )
            else
                call s:RunIfTool(a:idx + 1)
            endif
        endfunction

        call s:RunIfTool(0)

        return ( tool_uses > 0 )
    endfunction

    return res
endfunction

function! vimqq#tools#toolset#format(tool_call)
    let root = ''
    let tools = [
        \ vimqq#tools#get_files#new(root),
        \ vimqq#tools#edit_file#new(root),
        \ vimqq#tools#create_file#new(root),
        \ vimqq#tools#run_cmd#new(root)
    \ ]
    for tool in tools
        if tool.name() ==# a:tool_call['name']
            return tool.format_call(a:tool_call['input'])
        endif
    endfor
    call vimqq#log#error('Unknown tool: ' . a:tool_call['name'])
    return "\n\n[tool_call: unknown tool " . a:tool_call['name'] . "]"
endfunction

