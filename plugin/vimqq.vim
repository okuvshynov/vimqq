command! -range -nargs=+ QQ call vimqq#cmd#dispatch(<count>, <line1>, <line2>, <q-args>)
command! -range -nargs=+ QQN call vimqq#cmd#dispatch_new(<count>, <line1>, <line2>, <q-args>)
command! -range -nargs=+ QQI call vimqq#cmd#dispatch_index(<count>, <line1>, <line2>, <q-args>)

command! -nargs=0 QQList call vimqq#cmd#show_list()
command! -nargs=0 QQFZF  call vimqq#cmd#fzf()

" we autoload to allow autowarmup in command line
if !has_key(g:, 'vqq_skip_init')
    call vimqq#cmd#init()
endif
