command! -range -nargs=+ QQ call vimqq#main#dispatch(<count>, <line1>, <line2>, <q-args>)
command! -range -nargs=+ QQN call vimqq#main#dispatch_new(<count>, <line1>, <line2>, <q-args>)
command! -range -nargs=+ QQI call vimqq#main#dispatch_index(<count>, <line1>, <line2>, <q-args>)
command! -range -nargs=+ QQT call vimqq#main#dispatch_tools(<count>, <line1>, <line2>, <q-args>)

command! -nargs=0 QQLIST call vimqq#main#show_list()
command! -nargs=0 QQFZF  call vimqq#main#fzf()

" debugging commands
command! -nargs=0 QQLOG execute 'vertical split ' . vimqq#log#file()

command! -nargs=0 QQG   call vimqq#indexing#graph#build_graph()
command! -nargs=0 QQGI  call vimqq#indexing#graph#build_index()
command! -nargs=0 QQS   call vimqq#main#status_show()

" we autoload to allow autowarmup in command line
" and indexing if configured
if !has_key(g:, 'vqq_skip_init')
    call vimqq#main#init()
endif
