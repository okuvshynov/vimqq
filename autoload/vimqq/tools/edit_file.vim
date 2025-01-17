if exists('g:autoloaded_vimqq_tools_edit_file_module')
    finish
endif

let g:autoloaded_vimqq_tools_edit_file_module = 1

function! vimqq#tools#edit_file#new(root) abort
    let tool = {}

    let tool._root = a:root

    function! tool.name() dict
        return 'edit_file'
    endfunction

    function! tool.schema() dict
        return {
        \ "type": "function",
        \   "function": {
        \     "name": "edit_file",
        \     "description": "Replaces a single string with another string in file. Both needle and replacement can contain newlines. Make sure to identify the string and replacement in such a way, that only one occurence exist. Include extra context around needle and replacement if needed to ensure uniqueness",
        \     "parameters": {
        \       "type": "object",
        \       "properties": {
        \         "filepath": {
        \           "type": "string",
        \           "description": "file path to run replacement"
        \         },
        \         "needle": {
        \           "type": "string",
        \           "description": "string to search for in existing file. make sure that only one occurence exist. include extra context around the string if needed"
        \         },
        \         "replacement": {
        \           "type": "string",
        \           "description": "string replace needle with."
        \         }
        \       }, 
        \       "required": ["filepath", "needle", "replacement"],
        \     },
        \   },
        \ }
    endfunction

    function! tool.run(tool_use_args) abort
        let res = []
        let path = a:tool_use_args['filepath']
        let needle = a:tool_use_args['needle']
        let replacement = a:tool_use_args['replacement']

        let file_path = self._root . '/' . path
        if filereadable(file_path)
            " Read the entire file content
            let content = join(readfile(file_path), "\n")
            
            " Count occurrences of the needle
            let cnt = 0
            let pos = 0
            while 1
                let pos = stridx(content, needle, pos)
                if pos == -1
                    break
                endif
                let cnt += 1
                let pos += 1
            endwhile

            if cnt == 0
                call add(res, '')
                call add(res, path)
                call add(res, 'ERROR: Pattern not found in file.')
            elseif cnt > 1
                call add(res, '')
                call add(res, path)
                call add(res, 'ERROR: Multiple instances of pattern found.')
            else
                " Perform the replacement
                " TODO: vim is doing some magic with substitute.
                let pos = stridx(content, needle, 0)

                let new_content = substitute(content, '\V' . escape(needle, '\'), replacement, '')
                
                " Write back to file
                let lines = split(new_content, "\n", 1)
                call writefile(lines, file_path)
                
                call add(res, '')
                call add(res, path)
                call add(res, 'SUCCESS: File updated successfully.')
            endif
        else
            call add(res, '')
            call add(res, path)
            call add(res, 'ERROR: File not found.')
        endif

        return join(res, '\n')
    endfunction

    return tool

endfunction
