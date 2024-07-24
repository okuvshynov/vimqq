" Copyright 2024 Oleksandr Kuvshynov
set nocompatible
syntax on

" This is an example configuration.

" -----------------------------------------------------------------------------
" Local llama configuration

" Example commands to start the server:
" Larger 70B model:
" ./llama.cpp/llama-server --model ./llms/gguf/llama3.70b.q8.inst.gguf --chat-template llama3 --host 0.0.0.0 --port 8080
"
" Smaller 8B model:
" ./llama.cpp/llama-server --model ./llms/gguf/llama3.8b.q8.inst.gguf --chat-template llama3 --host 0.0.0.0  --port 8088
"
" Now we can define the endpoint(s). In the example below we configure two
" instances. bot_name will be used to tag the bot, for configuration and be
" shown in chat history interface, so make it somewhat descriptive.

let g:vqq_llama_servers = [
    \ {'bot_name': 'llama70', 'addr': 'http://studio.local:8080'}
\]

" -----------------------------------------------------------------------------
" Anthropic models configuration
"
" If you plan to use claude models, you'll need to register and get API key
" with some credits. 
" You need to make your claude API key available to the script. By default, 
" we are looking for API key in environment variable $ANTHROPIC_API_KEY, but
" you can override that here:
"
" let g:vqq_claude_api_key = 

" Once we have that, we can add claude model as well:

let g:vqq_claude_models = [
    \ {'bot_name': 'sonnet', 'model': 'claude-3-5-sonnet-20240620'}
\]

""" Example key mappings
" [w]armup llama70b
xnoremap <silent> <leader>w :<C-u>call VQQWarmup('@llama70')<cr>
" [w]armup new chat llama70b
xnoremap <silent> <leader>ww :<C-u>call VQQWarmupNew('@llama70')<cr>

" [W]armup llama70b with extra context
xnoremap <silent> <leader>W :<C-u>call VQQWarmupEx('@llama70')<cr>
" [w]armup new chat llama70b with extra context
xnoremap <silent> <leader>WW :<C-u>call VQQWarmupNewEx('@llama70')<cr>

" Chat [l]ist
nnoremap <silent> <leader>ll :<C-u>execute 'VQQList'<cr>

"" 
" More key mappings for specific tasks
"
" [E]xplain
xnoremap <silent> <leader>E :<C-u>execute "'<,'>VQQSendNewCtx @llama70 Explain how this code works."<cr>
" [I]mprove
xnoremap <silent> <leader>I :<C-u>execute "'<,'>VQQSendNewCtx @llama70 How would you improve this code?"<cr>
