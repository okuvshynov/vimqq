" Copyright 2024 Oleksandr Kuvshynov
" 
" AI plugin for Vim/NeoVim with focus on local evaluation, flexible context
" and aggressive cache warmup to hide latency.
" Version: 0.0.6

" -----------------------------------------------------------------------------
"  Universal command

"  format is 
"     :QQ [bot_tag] message
"  example:
"     :%QQ @llama How would you refactor this file?

command! -range -nargs=+ QQ call vimqq#cmd#dispatch(<count>, <line1>, <line2>, <q-args>)
command! -range -nargs=+ QQN call vimqq#cmd#dispatch_new(<count>, <line1>, <line2>, <q-args>)
command! -range -nargs=+ QQI call vimqq#cmd#dispatch_index(<count>, <line1>, <line2>, <q-args>)

" ref gen command
command! -nargs=+ QREF call vimqq#cmd#qref(<q-args>)

command! -nargs=0 QQList call vimqq#cmd#show_list()
command! -nargs=0 QQFZF  call vimqq#cmd#fzf()

if !has_key(g:, 'vqq_skip_init')
    call vimqq#cmd#init()
endif
