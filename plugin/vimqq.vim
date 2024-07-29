" Copyright 2024 Oleksandr Kuvshynov

" -----------------------------------------------------------------------------
"  commands. this is the API for the plugin
command!        -nargs=+ VQQSend         call vimqq#main#send_message("ctx_none",  v:false, <q-args>)
command!        -nargs=+ VQQSendNew      call vimqq#main#send_message("ctx_none",  v:true,  <q-args>)
command! -range -nargs=+ VQQSendCtx      call vimqq#main#send_message("ctx_range", v:false, <q-args>)
command! -range -nargs=+ VQQSendNewCtx   call vimqq#main#send_message("ctx_range", v:true,  <q-args>)

" gets bot name as parameter optionally
command!        -nargs=? VQQWarm         call vimqq#main#send_warmup("ctx_none",  v:false, <q-args>)
command!        -nargs=? VQQWarmNew      call vimqq#main#send_warmup("ctx_none",  v:true,  <q-args>)
command! -range -nargs=? VQQWarmCtx      call vimqq#main#send_warmup("ctx_range", v:false, <q-args>)
command! -range -nargs=? VQQWarmNewCtx   call vimqq#main#send_warmup("ctx_range", v:true,  <q-args>)

" extra context using ctags
command! -range -nargs=+ VQQSendCtxEx    call vimqq#main#send_message("ctx_ctags", v:false, <q-args>)
command! -range -nargs=+ VQQSendNewCtxEx call vimqq#main#send_message("ctx_ctags", v:true,  <q-args>)
command! -range -nargs=? VQQWarmCtxEx    call vimqq#main#send_warmup("ctx_ctags",  v:false, <q-args>)
command! -range -nargs=? VQQWarmNewCtxEx call vimqq#main#send_warmup("ctx_ctags",  v:true,  <q-args>)

command!        -nargs=0 VQQList         call vimqq#main#show_list()
command!        -nargs=1 VQQOpenChat     call vimqq#main#show_chat(<f-args>)
command!        -nargs=0 VQQToggle       call vimqq#main#toggle()

" exprerimental, huge context
command! -range -nargs=+ VQQSendNewCtxFull call vimqq#main#send_message("ctx_full", v:true, <q-args>)
command! -range -nargs=+ VQQWarmNewCtxFull call vimqq#main#send_warmup("ctx_full",  v:true, <q-args>)
command! -range -nargs=+ VQQSendNewCtxFile call vimqq#main#send_message("ctx_file", v:true, <q-args>)
command! -range -nargs=+ VQQWarmNewCtxFile call vimqq#main#send_warmup("ctx_file",  v:true, <q-args>)
" -----------------------------------------------------------------------------
"  Wrapper helper functions, useful for key mappings definitions
function! VQQWarmupEx(bot)
    execute 'VQQWarmCtxEx ' . a:bot 
    call feedkeys(":'<,'>VQQSendCtxEx " . a:bot . " ", 'n')
endfunction

function! VQQWarmupNewEx(bot)
    execute 'VQQWarmNewCtxEx ' . a:bot 
    call feedkeys(":'<,'>VQQSendNewCtxEx " . a:bot . " ", 'n')
endfunction

function! VQQWarmup(bot)
    execute 'VQQWarmCtx ' . a:bot 
    call feedkeys(":'<,'>VQQSendCtx " . a:bot . " ", 'n')
endfunction

function! VQQWarmupNew(bot)
    execute 'VQQWarmNewCtx ' . a:bot 
    call feedkeys(":'<,'>VQQSendNewCtx " . a:bot . " ", 'n')
endfunction

function! VQQQuery(bot)
    call feedkeys(":VQQSend " . a:bot . " ", 'n')
endfunction

function! VQQQueryNew(bot)
    call feedkeys(":VQQSendNew " . a:bot . " ", 'n')
endfunction

function! VQQWarmupDuoNew(wbot, qbot)
    execute 'VQQWarmNewCtx ' . a:wbot 
    call feedkeys(":'<,'>VQQSendNewCtx " . a:qbot . " ", 'n')
endfunction

function! VQQWarmupDuoNewFull(wbot, qbot)
    execute 'VQQWarmNewCtxFull ' . a:wbot 
    call feedkeys(":'<,'>VQQSendNewCtxFull " . a:qbot . " ", 'n')
endfunction

function! VQQWarmupDuoNewFile(wbot, qbot)
    execute 'VQQWarmNewCtxFile ' . a:wbot 
    call feedkeys(":'<,'>VQQSendNewCtxFile " . a:qbot . " ", 'n')
endfunction


