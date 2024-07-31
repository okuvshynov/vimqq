" Copyright 2024 Oleksandr Kuvshynov

" -----------------------------------------------------------------------------
"  Universal command

"  format is 
"     :QQ [options] [bot_tag] message
"  example:
"     :QQ -nwf @llama How would you refactor this file?
"  Supported options:
"  - n - [n]ew chat
"  - w - do [w]armup
"  - s - use visual [s]election as context
"  - f - use current [f]ile as context
"  - p - use entire [p]roject as context -- be careful here
"  - t - use c[t]ags from the selection as context
command! -range -nargs=+ QQ call vimqq#main#qq(<q-args>)
command!        -nargs=+ Q  call vimqq#main#q(<q-args>)

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
command!        -nargs=1 QQOpenChat call vimqq#main#show_chat(<f-args>)
command!        -nargs=0 QQToggle   call vimqq#main#toggle()
