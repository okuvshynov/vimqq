" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_mistral_module')
    finish
endif

let g:autoloaded_vimqq_mistral_module = 1

" API key for mistral
let g:vqq_mistral_api_key = get(g:, 'vqq_mistral_api_key', $MISTRAL_API_KEY)

function! vimqq#bots#mistral#new(config = {}) abort
    " Start with base bot
    let l:mistral_bot = vimqq#bots#openai#new(extend(
        \ {'bot_name': 'mistral'}, 
        \ a:config))
    
    let l:mistral_bot._api_key = g:vqq_mistral_api_key

    function! l:mistral_bot._send_query(req, job_conf) dict
        let l:json_req = json_encode(a:req)
        let l:headers = {
            \ 'Content-Type': 'application/json',
            \ 'Accept': 'application/json',
            \ 'Authorization': 'Bearer ' . self._api_key
        \ }
        return vimqq#platform#http_client#post(
            \ 'https://api.mistral.ai/v1/chat/completions',
            \ l:headers,
            \ l:json_req,
            \ a:job_conf)
    endfunction

    return l:mistral_bot

endfunction
