if exists('g:autoloaded_vimqq_tools_schema')
    finish
endif

let g:autoloaded_vimqq_tools_schema = 1


" This is an utility to translate tool definition schemas.
" For example, Anthropic is using slightly different format.

function! vimqq#tools#schema#to_claude(schema)
    let l:fn = a:schema['function']
    let l:res = {
    \   'name': l:fn['name'],
    \   'description' : l:fn['description'],
    \   'input_schema' : l:fn['parameters']
    \} 
    return l:res
endfunction

