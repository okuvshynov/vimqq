if exists('g:autoloaded_vimqq_gemini_module')
    finish
endif

let g:autoloaded_vimqq_gemini_module = 1

function! vimqq#bots#gemini#new(config = {}) abort
    let api = vimqq#api#gemini_api#new({})
    
    " Create a new bot instance using the base bot class
    return vimqq#bots#bot#new(api, a:config)
endfunction
