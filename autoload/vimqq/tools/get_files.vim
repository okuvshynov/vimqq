if exists('g:autoloaded_vimqq_tools_get_files_module')
    finish
endif

let g:autoloaded_vimqq_tools_get_files_module = 1

let s:TOOL_FOLD_LIMIT = 400

function! vimqq#tools#get_files#new(root) abort
    let tool = {}

    let tool._root = a:root

    function! tool.name() dict
        return 'get_files'
    endfunction

    function! tool.schema() dict
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

    function! tool.run(tool_use_args) abort
        let res = []
        let paths = a:tool_use_args['filepaths']

        for p in paths
            let file_path = self._root . '/' . p
            if filereadable(file_path)
                call add(res, '')
                call add(res, p)
                call add(res, join(readfile(file_path), "\n"))
            else
                call add(res, '')
                call add(res, p)
                call add(res, 'ERROR: File not found.')
            endif
        endfor

        return join(res, "\n")
    endfunction

    function! tool.run_async(tool_use_args, callback) abort
        let result = self.run(a:tool_use_args)
        call a:callback(result)
    endfunction

    function! tool.format_call(tool_use_args) dict abort
        let paths = a:tool_use_args['filepaths']
        let path_list = join(paths, "\n")
        let output = "[tool_call: get_files]\n" . path_list
        if len(path_list) > s:TOOL_FOLD_LIMIT
            let output = "{{{ " . output . "\n}}}"
        endif
        return "\n" . output . "\n\n"
    endfunction

    return tool

endfunction

