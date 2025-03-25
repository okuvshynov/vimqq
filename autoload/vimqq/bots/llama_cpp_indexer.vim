if exists('g:autoloaded_vimqq_llama_cpp_indexer')
    finish
endif

let g:autoloaded_vimqq_llama_cpp_indexer = 1

" TODO: configure
let s:MAX_TOKENS = 1024

function vimqq#bots#llama_cpp_indexer#new(config = {})
    let bot = {}
    let config = {}
    let config.endpoint = substitute(a:config.addr, '/*$', '', '')

    let bot.api = vimqq#api#llama_api#new(config)

    " request has 2 required fields for now:
    "  - on_complete callback
    "  - content - string to count tokens
    function bot.count_tokens(request) dict
        let req = a:request
        call self.api.tokenize(req.content, {'on_complete': {t -> req.on_complete(len(t))}})
    endfunction

    " request has following fields:
    "   - on_complete callback
    "   - on_error    callback
    "   - content     content to send as text message
    function bot.message(request) dict
        let messages = [
        \   {'role': 'user', 'content' : get(a:request, 'content', '')}
        \ ]

        let req = {
        \   'messages' : messages,
        \   'max_tokens' : s:MAX_TOKENS,
        \   'on_complete': {err, p, m -> err is v:null ? a:request.on_complete(m.content[0].text) : a:request.on_error(err)},
        \   'stream' : v:false
        \ }

        call self.api.chat(req)
    endfunction

    return bot
endfunction
