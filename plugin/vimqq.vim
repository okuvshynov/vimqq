command! -range -nargs=+ QQ call vimqq#main#dispatch(<count>, <line1>, <line2>, <q-args>)
command! -range -nargs=+ QQN call vimqq#main#dispatch_new(<count>, <line1>, <line2>, <q-args>)
command! -range -nargs=+ QQI call vimqq#main#dispatch_index(<count>, <line1>, <line2>, <q-args>)
command! -range -nargs=+ QQT call vimqq#main#dispatch_tools(<count>, <line1>, <line2>, <q-args>)

command! -nargs=0 QQList call vimqq#main#show_list()
command! -nargs=0 QQFZF  call vimqq#main#fzf()

" debugging commands
command! -nargs=0 QQLOG execute 'vertical split ' . vimqq#log#file()

" we autoload to allow autowarmup in command line
if !has_key(g:, 'vqq_skip_init')
    call vimqq#main#init()
endif
