if exists('g:autoloaded_vimqq_api_module')
    finish
endif

let g:autoloaded_vimqq_api_module = 1

" this is OpenAI-like API implemented in vimscript

function! vimqq#api#api#new() abort
    let l:api = {}

    function! l:api.chat(params)
        let l:model = get(a:params, 'model', '')
        " includes system messages
        let l:messages = get(a:params, 'messages', '')
        let l:max_tokens = get(a:params, 'max_tokens', '')
        let l:stream = get(a:params, 'stream', v:false)
        let l:on_chunk = get(a:params, 'on_chunk', v:none)
        let l:on_complete = get(a:params, 'on_complete', v:none)
    endfunction

endfunction

