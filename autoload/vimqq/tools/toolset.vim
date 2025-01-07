if exists('g:autoloaded_vimqq_tools_toolset_module')
    finish
endif

let g:autoloaded_vimqq_tools_toolset_module = 1

function! s:find_lucas_root()
    let l:current_dir = expand('%:p:h')
    let l:prev_dir = ''

    while l:current_dir != l:prev_dir
        " Check if lucas.idx file exists in current dir
        let l:file_path = l:current_dir . '/lucas.idx'
        if filereadable(l:file_path)
            return l:current_dir
        endif

        let l:prev_dir = l:current_dir
        let l:current_dir = fnamemodify(l:current_dir, ':h')
    endwhile
    return v:null
endfunction

function! vimqq#tools#toolset#new()
    let res = {}

    let res.tools = [vimqq#tools#get_files#new(s:find_lucas_root())]

    function! res.def(is_claude) dict
        let tool = self.tools[0].schema()
        if a:is_claude
            let tool = vimqq#tools#schema#to_claude(tool)
        endif
        return [tool]
    endfunction

    return res
endfunction
