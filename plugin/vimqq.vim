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
command! -range -nargs=+ QQ call vimqq#main#qq(<f-args>)
command!        -nargs=+ Q  call vimqq#main#qq(<f-args>)

