if exists('g:autoloaded_vimqq_tools_create_file_module')
    finish
endif

let g:autoloaded_vimqq_tools_create_file_module = 1

function! vimqq#tools#create_file#new(root) abort
    let tool = {}

    let tool._root = a:root

    function! tool.name() dict
        return 'create_file'
    endfunction

    function! tool.schema() dict
        return {
        \ "type": "function",
        \   "function": {
        \     "name": "create_file",
        \     "description": "Creates new file with provided context. If file already exists, does nothing",
        \     "parameters": {
        \       "type": "object",
        \       "properties": {
        \         "filepath": {
        \           "type": "string",
        \           "description": "file path to create"
        \         },
        \         "content": {
        \           "type": "string",
        \           "description": "New file content."
        \         }
        \       },
        \       "required": ["filepath", "content"],
        \     },
        \   },
        \ }
    endfunction

    function! tool.run(tool_use_args) abort
        let res = []
        let path = a:tool_use_args['filepath']
        let content = a:tool_use_args['content']

        let file_path = self._root . '/' . path
        
        " Check if file already exists
        if filereadable(file_path)
            call add(res, '')
            call add(res, path)
            call add(res, 'ERROR: File already exists.')
        else
            " Write content to file
            let lines  = split(content, "\n", 1)
            let status = writefile(lines, file_path, 'b')
            
            call add(res, '')
            call add(res, path)
            if status == 0
                call add(res, 'SUCCESS: File created successfully.')
            else
                call add(res, 'ERROR: Unable to create file')
            endif
        endif

        return join(res, "\n")
    endfunction

    function! tool.run_async(tool_use_args, callback) dict abort
        let result = self.run(a:tool_use_args)
        call a:callback(result)
    endfunction

    function! tool.format_call(tool_use_args) dict abort
        let path = a:tool_use_args['filepath']
        let content = a:tool_use_args['content']
        let COLLAPSE_WHEN_OVER_N = 5
        if count(content, "\n") > COLLAPSE_WHEN_OVER_N
            let content = "{{{ " . content . "\n}}}"
        endif
        let output = ">>> create_file('" . path . "', \"\"\""

        return "\n" . output . "\n" . content . "\n\"\"\")" . "\n\n"
    endfunction
    
    return tool

endfunction
