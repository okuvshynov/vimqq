" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_groq_module')
    finish
endif

let g:autoloaded_vimqq_groq_module = 1

" API key for groq
let g:vqq_groq_api_key = get(g:, 'vqq_groq_api_key', $GROQ_API_KEY)

function! vimqq#bots#groq#new(config = {}) abort
    " Start with base bot
    let l:groq_bot = vimqq#bots#openai#new(extend(
        \ {'bot_name': 'groq'}, 
        \ a:config))
    
    let l:groq_bot._api_key = g:vqq_groq_api_key

    function! l:groq_bot._send_query(req, job_conf) dict
        let l:json_req = json_encode(a:req)
        let l:headers = {
            \ 'Content-Type': 'application/json',
            \ 'Authorization': 'Bearer ' . self._api_key
        \ }
        return vimqq#platform#http_client#post(
            \ 'https://api.groq.com/openai/v1/chat/completions',
            \ l:headers,
            \ l:json_req,
            \ a:job_conf)
    endfunction

    return l:groq_bot

endfunction
