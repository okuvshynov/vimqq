" Copyright 2024 Oleksandr Kuvshynov
set nocompatible
syntax on

" -----------------------------------------------------------------------------
" Local llama configuration

" Example commands to start the server:
" ./llama.cpp/llama-server --model ./llms/gguf/llama3.70b.q8.inst.gguf --chat-template llama3 --host 0.0.0.0 --top_p 0.0 --top_k 1 --port 8080
" ./llama.cpp/llama-server --model ./llms/gguf/llama3.8b.q8.inst.gguf --chat-template llama3 --host 0.0.0.0 --top_p 0.0 --top_k 1 --port 8088
let g:vqq_llama_servers = [
      \  {'bot_name': 'llama8', 'addr': 'http://studio.local:8088'},
      \  {'bot_name': 'llama70', 'addr': 'http://studio.local:8080'}
\]

" optional parameters for llama server config:
"  - max_tokens: how many tokens to generate. default: 1024
"  - title_tokens: how many tokens to generate to get title. default: 16
"  - healthcheck_ms: how often to issue healthcheck query. default: 10000 (=10s)


" -----------------------------------------------------------------------------
" Anthropic models configuration

let g:vqq_claude_models = [
      \  {'bot_name': 'sonnet', 'model': 'claude-3-5-sonnet-20240620'}
\]

" optional parameters for claude config:
"  - max_tokens: how many tokens to generate. default: 1024
"  - title_tokens: how many tokens to generate to get title. default: 16
" API key. default is environment variable $ANTHROPIC_API_KEY
" let g:vqq_claude_api_key = 


" -----------------------------------------------------------------------------
" Other configuration
"
" default bot is the one used if you don't use @bot_name tag in your question
" it is also one where warmup query would be sent by default. Note that
" for claude models warmup is no-op.
" if vqq_default_bot is not configured, first of the available clients will be
" used as default
"
" let g:vqq_default_bot = 'llama70'
"
" chat window width (default = 80)
" let g:vqq_width = 120
"
" time format to use for chats in chatlist. Default is '%Y-%m-%d %H:%M:%S '.
" Individual message time format is fixed to be '%H:%M:%S' so that it is
" easier to create syntax rules for highlighting
" let g:vqq_time_format = '%H:%M:%S '
"
" json file to store all the message history (default = ~/.vim/vqq_chars.json)
" let g:vqq_chats_file = expand('~/.vim/vqq_history.json')

source vimqq.vim
