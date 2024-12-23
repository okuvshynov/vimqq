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
command! -range -nargs=+ QQ <line1>,<line2>call vimqq#main#qq(<q-args>)
command!        -nargs=+ Q  call vimqq#main#q(<q-args>)
command! -range -nargs=+ QQN <line1>,<line2>call vimqq#main#qqn(<q-args>)
command!        -nargs=+ QN  call vimqq#main#qn(<q-args>)

" Fork the current chat reusing the context from the first message.
" It is useful in cases of long context, but when you want to start a new
" discussion thread. For example,
"   :QF Suggest a simple task for junior engineer working on the project
"
" It will:
"   - take current chat's first message, keep the context and bot 
"   - modify the question with 'Suggest a ...'
"   - create new chat
"   - append amended message to new chat
"   - send new chat to the original bot
"
" This way we can reuse the context, which might be long (entire file/project)
command!        -nargs=+ QF call vimqq#main#fork_chat(<q-args>)

command!        -nargs=0 QQList     call vimqq#main#show_list()
command!        -nargs=0 QQFZF      call vimqq#main#fzf()
command!        -nargs=1 QQOpenChat call vimqq#main#show_chat(<f-args>)
command!        -nargs=0 QQChat     call vimqq#main#show_current_chat()

if !has_key(g:, 'vqq_skip_init')
    call vimqq#main#init()
endif
