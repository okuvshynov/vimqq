" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_deepseek_module')
    finish
endif

let g:autoloaded_vimqq_deepseek_module = 1

" API key for groq
let g:vqq_deepseek_api_key = get(g:, 'vqq_deepseek_api_key', $DEEPSEEK_API_KEY)

function! vimqq#bots#deepseek#new(config = {}) abort
    " Start with base bot
    let l:bot = vimqq#bots#openai#new(extend(
        \ {'bot_name': 'deepseek'}, 
        \ a:config))
    
    let l:bot._api_key = g:vqq_deepseek_api_key

    function! l:bot._send_query(req, job_conf) dict
        let l:json_req = json_encode(a:req)
        let l:headers = {
            \ 'Content-Type': 'application/json',
            \ 'Accept': 'application/json',
            \ 'Authorization': 'Bearer ' . self._api_key
        \ }
        return vimqq#platform#http_client#post(
            \ 'https://api.deepseek.com/chat/completions',
            \ l:headers,
            \ l:json_req,
            \ a:job_conf)
    endfunction

    return l:bot
endfunction
