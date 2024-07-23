" Copyright 2024 Oleksandr Kuvshynov
set nocompatible
syntax on

" This is an example configuration file. You can think of it as something you
" can put into your vimrc file.

" -----------------------------------------------------------------------------
" Local llama configuration

" Local model evaluation is done using llama.cpp server: 
"   https://github.com/ggerganov/llama.cpp/tree/master/examples/server
"
" Easiest way to get it seems to be to build from source. Clone llama.cpp
" repo, build with make and you should have llama-server binary ready.
" Check llama.cpp docs to see how to enable CUDA if you running on GPU.
" 
" Example commands to start the server:
" ./llama.cpp/llama-server --model ./llms/gguf/llama3.70b.q8.inst.gguf --chat-template llama3 --host 0.0.0.0 --top_p 0.0 --top_k 1 --port 8080
" ./llama.cpp/llama-server --model ./llms/gguf/llama3.8b.q8.inst.gguf --chat-template llama3 --host 0.0.0.0 --top_p 0.0 --top_k 1 --port 8088
" These commands would do greedy sampling which might be not the best option
" for your use-case. remove top_p and top_k options to make it non-greedy.

" Now we can define the endpoint(s). In the example below we configure two
" instances. bot_name is something you'll use to tag the bot and in
" configuration below, so make it somewhat descriptive.

let g:vqq_llama_servers = [
      \  {'bot_name': 'llama8', 'addr': 'http://studio.local:8088'},
      \  {'bot_name': 'llama70', 'addr': 'http://studio.local:8080'}
\]

" you can add more optional parameters to the dictionary:
"  - max_tokens: how many tokens to generate. default: 1024
"  - title_tokens: how many tokens to generate to get title. default: 16
"  - healthcheck_ms: how often to issue healthcheck query. default: 10000 (=10s)

" -----------------------------------------------------------------------------
" Anthropic models configuration
"
" If you plan to use claude models, you'll need to register and get API key
" with some credits. Once you have that, you can add claude model as well:

let g:vqq_claude_models = [
      \  {'bot_name': 'sonnet', 'model': 'claude-3-5-sonnet-20240620'}
\]

" optional parameters for claude config:
"  - max_tokens: how many tokens to generate. default: 1024
"  - title_tokens: how many tokens to generate to get title. default: 16
"
" You need to make your claude API key available to the script. By default, 
" we are looking for API key in environment variable $ANTHROPIC_API_KEY, but
" you can override that here:
"
" let g:vqq_claude_api_key = 


" -----------------------------------------------------------------------------
" Other configuration
"
" default bot is the one used if you don't use @bot_name tag in your question.
" if vqq_default_bot is not configured, first of the available clients will be
" used as default
"
" let g:vqq_default_bot = 'llama70'
"
" chat window width (default = 80)
" let g:vqq_width = 120
"
" time format to use for chats in chatlist. Default is '%b %d %H:%M '.
" Individual message time format is fixed to be '%H:%M' so that it is
" easier to create syntax rules for highlighting
" let g:vqq_time_format = '%H:%M:%S '
"
" json file to store all the message history (default = ~/.vim/vqq_chars.json)
" let g:vqq_chats_file = expand('~/.vim/vqq_history.json')

" vimqq provides basic commands which we can combine to get convenient
" shortcuts.

" defining helper functions:
" send warmup query to bot, including the visual selection and current chat.
function! VQQWarmup(bot)
    execute 'VQQWarmCtx ' . a:bot 
    call feedkeys(":'<,'>VQQSendCtx " . a:bot . " ", 'n')
endfunction

" send warmup query to bot, including the visual selection in a new chat
function! VQQWarmupNew(bot)
    execute 'VQQWarmNewCtx ' . a:bot 
    call feedkeys(":'<,'>VQQSendNewCtx " . a:bot . " ", 'n')
endfunction

" send a query to the bot within current chat.
function! VQQQuery(bot)
    call feedkeys(":VQQSend " . a:bot . " ", 'n')
endfunction

" send a message to the bot in newly started chat session
function! VQQQueryNew(bot)
    call feedkeys(":VQQSendNew " . a:bot . " ", 'n')
endfunction


""" Example key mappings

" [w]armup llama70b
xnoremap <silent> <leader>w :<C-u>call VQQWarmup('@llama70')<cr>
" [w]armup new chat llama70b
xnoremap <silent> <leader>ww :<C-u>call VQQWarmupNew('@llama70')<cr>

" [q]uery llama70b
nnoremap <silent> <leader>q :<C-u>call VQQQuery('@llama70')<cr>
nnoremap <silent> <leader>qq :<C-u>call VQQQueryNew('@llama70')<cr>

" query [s]onnet
nnoremap <silent> <leader>s :<C-u>call VQQQuery('@sonnet')<cr>
nnoremap <silent> <leader>ss :<C-u>call VQQQueryNew('@sonnet')<cr>

" Chat [l]ist
nnoremap <silent> <leader>ll :<C-u>execute 'VQQList'<cr>


"" 
" More key mappings for specific tasks

" [R]eview code
xnoremap <silent> <leader>R :<C-u>execute "'<,'>VQQSendNewCtx @llama70 please review the code and share suggestions for improvement."<cr>

" find [c]orner cases
xnoremap <silent> <leader>c :<C-u>execute "'<,'>VQQSendNewCtx @llama70 What might be the corner cases that need to be handled?"<cr>

" [S]implify
xnoremap <silent> <leader>S :<C-u>execute "'<,'>VQQSendNewCtx @llama70 Can you simplify the code and make it more readable?"<cr>

" When you open the chat we can send warmup query to the bots so
" that initial part of prompt will be processed. As Claude has stateless API,
" there's no point having it here
let g:vqq_warmup_on_chat_open = ['llama70']

