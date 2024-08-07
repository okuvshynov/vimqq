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


" Warmup + prefill for visual selection
" [w]armup llama
xnoremap <leader>w  :<C-u>'<,'>QQ -ws @llama<cr>:'<,'>QQ -s @llama<Space>
" [w]armup llama in [n]ew chat
xnoremap <leader>wn :<C-u>'<,'>QQ -wns @llama<cr>:'<,'>QQ -ns @llama<Space>

" Warmup + prefill for query only in normal mode
" [w]armup llama
nnoremap <leader>w  :<C-u>Q -w @llama<cr>:Q @llama<Space>
" [w]armup llama in [n]ew chat
nnoremap <leader>wn :<C-u>Q -wn @llama<cr>:Q -n @llama<Space>

" Query without warmup
" [q]uery llama
nnoremap <leader>q :<C-u>Q @llama<Space>
" [q]uery llama in [n]ew chat
nnoremap <leader>qn :<C-u>Q -n @llama<Space>

" Warmup/query with entire file context
" [w]armup llama with entire [f]ile context
nnoremap <leader>wf :<C-u>Q -wf @llama<cr>:Q -f @llama<Space>
" [w]armup llama with entire [f]ile context in [n]ew chat
nnoremap <leader>wfn :<C-u>Q -wfn @llama<cr>:Q -fn @llama<Space>
" [w]armup llama with entire [f]ile context + [s]election
xnoremap <leader>wf :<C-u>'<,'>QQ -wfs @llama<cr>:'<,'>QQ -fs @llama<Space>
" [w]armup llama with entire [f]ile context + [s]election in [n]ew chat
xnoremap <leader>wfn :<C-u>'<,'>QQ -wfsn @llama<cr>:'<,'>QQ -fsn @llama<Space>

" [w]armup llama with c[t]agts following from the selection
xnoremap <leader>wt  :<C-u>'<,'>QQ -wst @llama<cr>:'<,'>QQ -st @llama<Space>
" [w]armup llama with c[t]agts following from the selection in [n]ew chat
xnoremap <leader>wtn :<C-u>'<,'>QQ -wnts @llama<cr>:'<,'>QQ -nts @llama<Space>

" [w]armup llama with entire [p]roject context
nnoremap <leader>wp :<C-u>Q -wp @llama<cr>:Q -p @llama<Space>
" [w]armup llama with entire [p]roject context in [n]ew chat
nnoremap <leader>wpn :<C-u>Q -wpn @llama<cr>:Q -pn @llama<Space>
" [w]armup llama with entire [p]roject context + [s]election
xnoremap <leader>wp :<C-u>'<,'>QQ -wps @llama<cr>:'<,'>QQ -ps @llama<Space>
" [w]armup llama with entire [p]roject context + [s]election in [n]ew chat
xnoremap <leader>wpn :<C-u>'<,'>QQ -wpsn @llama<cr>:'<,'>QQ -psn @llama<Space>

" [f]ork current chat
nnoremap <leader>f :<C-u>QF<Space>

" chat [l]ist
nnoremap <leader>ll :<C-u>QQList<cr>
" [t]oggle window
nnoremap <leader>qq :<C-u>QQToggle<cr>
