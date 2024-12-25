if exists('g:autoloaded_vimqq_tools_get_files_module')
    finish
endif

let g:autoloaded_vimqq_tools_get_files_module = 1

function! vimqq#tools#get_files#new(root) abort
    let l:tool = {}

    let l:tool._root = a:root

    function! l:tool.schema() abort
        let definition = {
        \ 'type': 'function',
        \ 'function': {
        \   'name': 'get_files',
        \   'description': 'Gets content of one or more files.',
        \   'parameters': {
        \     'type': 'object',
        \     'properties': {
        \       'filepaths': {
        \         'type': 'array',
        \         'items': {
        \           'type': 'string'
        \         },
        \         'description': 'A list of file paths to get the content.'
        \       }
        \     },
        \     'required': ['filepaths']
        \   }
        \ }
        \ }
        return definition
    endfunction

    function! l:tool.run(tool_use_args) abort
        let l:res = []
        let l:paths = a:tool_use_args['filepaths']

        for l:p in l:paths
            let l:file_path = self._root . '/' . l:p
            if filereadable(l:file_path)
                call add(l:res, '')
                call add(l:res, l:p)
                call add(l:res, join(readfile(l:file_path), "\n"))
            else
                call add(l:res, '')
                call add(l:res, l:p)
                call add(l:res, '!! This file was not found.')
            endif
        endfor

        return join(l:res, '\n')
    endfunction

    return l:tool

endfunction

