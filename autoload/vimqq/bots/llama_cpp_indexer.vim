if exists('g:autoloaded_vimqq_llama_cpp_indexer')
    finish
endif

let g:autoloaded_vimqq_llama_cpp_indexer = 1

function vimqq#bots#llama_cpp_indexer#new(config = {})
    let bot = {}
    let config = {}
    let config.endpoint = substitute(a:config.addr, '/*$', '', '')

    let bot.api = vimqq#api#llama_api#new(config)

    function bot.count_tokens(request) dict
        let req = a:request
        call self.api.tokenize(req.content, {'on_complete': {t -> req.on_complete(len(t))}})
    endfunction

    return bot
endfunction
