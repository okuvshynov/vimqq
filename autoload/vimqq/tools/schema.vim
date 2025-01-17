if exists('g:autoloaded_vimqq_tools_schema')
    finish
endif

let g:autoloaded_vimqq_tools_schema = 1


" This is an utility to translate tool definition schemas.
" For example, Anthropic is using slightly different format.

function! vimqq#tools#schema#to_claude(schema)
    let fn = a:schema['function']
    let res = {
    \   'name': fn['name'],
    \   'description' : fn['description'],
    \   'input_schema' : fn['parameters']
    \} 
    return res
endfunction

