" Copyright 2024 Oleksandr Kuvshynov
set nocompatible
syntax on

" This is an example configuration.

let g:vqq_width = 100

let g:vqq_llama_servers = [
      \  {'bot_name': 'llama', 'addr': 'http://studio.local:8080'}
\]

let g:vqq_claude_models = [
      \  {'bot_name': 'sonnet', 'model': 'claude-3-5-sonnet-20240620', 'max_tokens' : 4096}
\]

" [w]armup llama
xnoremap <leader>w  :<C-u>'<,'>QQ -ws @llama<cr>:'<,'>QQ -s @llama 
" [w]armup llama in [n]ew chat
xnoremap <leader>wn :<C-u>'<,'>QQ -wns @llama<cr>:'<,'>QQ -ns @llama 

" [q]uery llama
nnoremap <leader>q :<C-u>Q @llama 
" [q]uery llama in [n]ew chat
nnoremap <leader>qn :<C-u>Q -n @llama 

" [w]armup llama with entire [f]ile context
nnoremap <leader>wf :<C-u>Q -wf @llama<cr>:Q -f @llama 
" [w]armup llama with entire [f]ile context in [n]ew chat
nnoremap <leader>wfn :<C-u>Q -wfn @llama<cr>:Q -fn @llama 

" [w]armup llama with entire [p]roject context
nnoremap <leader>wp :<C-u>Q -wp @llama<cr>:Q -p @llama 
" [w]armup llama with entire [p]roject context in [n]ew chat
nnoremap <leader>wpn :<C-u>Q -wpn @llama<cr>:Q -pn @llama 

" [w]armup llama with [s]election + c[t]ags 
xnoremap <leader>wst :<C-u>'<,'>QQ -wst @llama<cr>:'<,'>QQ -st @llama 

" fork current chat
nnoremap <leader>f :<C-u>QF 
