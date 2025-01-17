if exists('g:autoloaded_vimqq_tools_edit_file_module')
    finish
endif

let g:autoloaded_vimqq_tools_edit_file_module = 1

function! vimqq#tools#edit_file#new(root) abort
    let l:tool = {}

    let l:tool._root = a:root

    function! l:tool.name() dict
        return 'edit_file'
    endfunction

    function! l:tool.schema() dict
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

    function! l:tool.run(tool_use_args) abort
        let l:res = []
        let l:path = a:tool_use_args['filepath']
        let l:needle = a:tool_use_args['needle']
        let l:replacement = a:tool_use_args['replacement']

        let l:file_path = self._root . '/' . l:path
        if filereadable(l:file_path)
            " Read the entire file content
            let l:content = join(readfile(l:file_path), "\n")
            
            " Count occurrences of the needle
            let l:count = 0
            let l:pos = 0
            while 1
                let l:pos = stridx(l:content, l:needle, l:pos)
                if l:pos == -1
                    break
                endif
                let l:count += 1
                let l:pos += 1
            endwhile

            if l:count == 0
                call add(l:res, '')
                call add(l:res, l:path)
                call add(l:res, 'ERROR: Pattern not found in file.')
            elseif l:count > 1
                call add(l:res, '')
                call add(l:res, l:path)
                call add(l:res, 'ERROR: Multiple instances of pattern found.')
            else
                " Perform the replacement
                " TODO: vim is doing some magic with substitute.
                let l:pos = stridx(l:content, l:needle, 0)

                let l:new_content = substitute(l:content, '\V' . escape(l:needle, '\'), l:replacement, '')
                
                " Write back to file
                let l:lines = split(l:new_content, "\n", 1)
                call writefile(l:lines, l:file_path)
                
                call add(l:res, '')
                call add(l:res, l:path)
                call add(l:res, 'SUCCESS: File updated successfully.')
            endif
        else
            call add(l:res, '')
            call add(l:res, l:path)
            call add(l:res, 'ERROR: File not found.')
        endif

        return join(l:res, '\n')
    endfunction

    return l:tool

endfunction
