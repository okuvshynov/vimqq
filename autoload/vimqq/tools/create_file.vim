if exists('g:autoloaded_vimqq_tools_create_file_module')
    finish
endif

let g:autoloaded_vimqq_tools_create_file_module = 1

function! vimqq#tools#create_file#new(root) abort
    let l:tool = {}

    let l:tool._root = a:root

    function! l:tool.name() dict
        return 'create_file'
    endfunction

    function! l:tool.schema() dict
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

    function! l:tool.run(tool_use_args) abort
        let l:res = []
        let l:path = a:tool_use_args['filepath']
        let l:content = a:tool_use_args['content']

        let l:file_path = self._root . '/' . l:path
        
        " Check if file already exists
        if filereadable(l:file_path)
            call add(l:res, '')
            call add(l:res, l:path)
            call add(l:res, 'ERROR: File already exists.')
        else
            " Write content to file
            let l:lines = split(l:content, "\n", 1)
            call writefile(l:lines, l:file_path, 'b')
            
            call add(l:res, '')
            call add(l:res, l:path)
            call add(l:res, 'SUCCESS: File created successfully.')
        endif

        return join(l:res, '\n')
    endfunction

    return l:tool

endfunction