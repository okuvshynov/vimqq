if exists('g:autoloaded_vimqq_cmdwatch')
    finish
endif

let g:autoloaded_vimqq_cmdwatch = 1

" if we sent warmup query, start timer 
let g:vqq_autowarm_cmd_ms = get(g:, 'vqq_autowarm_cmd_ms', 2500)

let s:cmdwatch = 'off'

function! s:_check_cmd(bot, messages)
    if mode() != 'c' || s:cmdwatch == 'off' || empty(a:messages)
        let s:cmdwatch = 'off'
        return
    endif

    let cmdline = getcmdline()

    call vimqq#log#debug('warmup cmdline: ' . cmdline)
    
    let l:tag = '@' . a:bot.name() . ' '
    " we assume that cmdline is '...{l:tag} message'

    let idx = stridx(cmdline, l:tag)
    if idx == -1
        let s:cmdwatch = 'off'
        return
    endif
    let l:message = strpart(cmdline, idx + strlen(l:tag))

    if a:messages[len(a:messages) - 1].message != l:message
        let a:messages[len(a:messages) - 1].message = l:message
        call a:bot.send_warmup(a:messages)
    else
        call vimqq#log#debug('message not changed')
    endif
    call timer_start(g:vqq_autowarm_cmd_ms, { -> s:_check_cmd(a:bot, a:messages)})
endfunction

function! vimqq#cmdwatch#start(bot, messages)
  " strictly greater
  if g:vqq_autowarm_cmd_ms > 0 && !empty(a:messages)
      let l:messages = deepcopy(a:messages)
      let s:cmdwatch = 'on'
      call timer_start(g:vqq_autowarm_cmd_ms, { -> s:_check_cmd(a:bot, l:messages)})
  endif
endfunction

function! vimqq#cmdwatch#stop()
    let s:cmdwatch = 'off'
endfunction
