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

    let res.tools = [vimqq#tools#get_files#new(root), vimqq#tools#edit_file#new(root), vimqq#tools#create_file#new(root)]

    function! res.def(is_claude) dict
        let res = []
        for tool in self.tools
            let schema = tool.schema()
            if a:is_claude
                let schema = vimqq#tools#schema#to_claude(schema)
            endif
            call add(res, schema)
        endfor
        return res
    endfunction

    function! res.run(tool_call) dict
        call vimqq#log#info('Calling tool: ' . string(a:tool_call))
        for tool in self.tools
            if tool.name() ==# a:tool_call['name']
                let res = tool.run(a:tool_call['input'])
                call vimqq#log#info(res)
                return res
            endif
        endfor
        call vimqq#log#error('Unknown tool: ' . a:tool_call['name'])
        return v:null
    endfunction

    function! res.run_async(tool_call, callback) dict
        call vimqq#log#info('Calling tool: ' . string(a:tool_call))
        for tool in self.tools
            if tool.name() ==# a:tool_call['name']
                let res = tool.run(a:tool_call['input'])
                call vimqq#log#info(res)
                call a:callback(res)
                return
            endif
        endfor
        call vimqq#log#error('Unknown tool: ' . a:tool_call['name'])
        call a:callback(v:null)
    endfunction

    return res
endfunction

