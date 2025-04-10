if exists('g:autoloaded_vimqq_tools_ctags_lookup_module')
    finish
endif

let g:autoloaded_vimqq_tools_ctags_lookup_module = 1

function! vimqq#tools#ctags_lookup#new(root) abort
    let tool = {}

    let tool._root = a:root

    function! tool.name() dict
        return 'ctags_lookup'
    endfunction

    function! tool.schema() dict
        return {
        \ "type": "function",
        \   "function": {
        \     "name": "ctags_lookup",
        \     "description": "Looks up symbols in ctags file that contain the provided symbol name",
        \     "parameters": {
        \       "type": "object",
        \       "properties": {
        \         "symbol": {
        \           "type": "string",
        \           "description": "Symbol name to look up in the ctags file"
        \         }
        \       },
        \       "required": ["symbol"],
        \     },
        \   },
        \ }
    endfunction

    function! tool.run(tool_use_args) abort dict
        let symbol = a:tool_use_args['symbol']
        let root = vimqq#indexing#io#root()
        
        if root is v:null
            return "ERROR: No project root found with .vqq directory."
        endif
        
        let tags_path = root . '/tags'
        
        if !filereadable(tags_path)
            return "ERROR: No tags file found at " . tags_path
        endif
        
        let matches = []
        
        for tagline in readfile(tags_path)
            let parts = split(tagline, '\t')
            if len(parts) >= 2 && parts[0] =~? symbol
                call add(matches, parts[0] . "\t" . parts[1])
            endif
        endfor
        
        if len(matches) == 0
            return "No matches found for symbol: " . symbol
        else
            return join(matches, "\n")
        endif
    endfunction

    function! tool.run_async(tool_use_args, callback) abort dict
        let result = self.run(a:tool_use_args)
        call a:callback(result)
    endfunction

    function! tool.format_call(tool_use_args) dict abort
        let symbol = a:tool_use_args['symbol']
        return "\n>>> ctags_lookup(" . symbol . ")\n\n"
    endfunction

    return tool
endfunction
