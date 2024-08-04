if exists('g:autoloaded_vimqq_cmdwatch')
    finish
endif

let g:autoloaded_vimqq_cmdwatch = 1

" if we sent warmup query, start timer 
let g:vqq_autowarm_cmd_ms = get(g:, 'vqq_autowarm_cmd_ms', 1000)

let s:cmdwatch = 'off'
" we use this for warmup
let s:messages = []
let s:bot = -1
let s:message_updated = v:false
let s:last_warmup_done = v:false

function! s:_send_warmup()
    if s:cmdwatch == 'on' && s:message_updated && s:last_warmup_done
        let s:message_updated = v:false
        let s:last_warmup_done = v:false
        call vimqq#log#debug('sending next warmup')
        call s:bot.send_warmup(s:messages)
    endif
endfunction

function! s:_check_cmd()
    call vimqq#log#debug('_check_cmd: ' . s:cmdwatch . " | " . len(s:messages))
    " TODO: do we need to check that mode() == 'c'?
    if s:cmdwatch == 'off' || empty(s:messages)
        let s:cmdwatch = 'off'
        let s:messages = []
        return
    endif

    let cmdline = getcmdline()

    call vimqq#log#debug('warmup cmdline: ' . cmdline)
    
    let l:tag = '@' . s:bot.name() . ' '
    " we assume that cmdline is 'some options here {l:tag} message'

    let idx = stridx(cmdline, l:tag)
    if idx == -1
        let s:cmdwatch = 'off'
        let s:messages = []
        return
    endif
    let l:message = strpart(cmdline, idx + strlen(l:tag))

    if s:messages[len(s:messages) - 1].message != l:message
        let s:messages[len(s:messages) - 1].message = l:message
        let s:message_updated = v:true
    else
        call vimqq#log#debug('message not changed')
    endif
endfunction

function! s:_cmd_loop()
    call s:_check_cmd()
    call s:_send_warmup()
    call timer_start(g:vqq_autowarm_cmd_ms, { -> s:_cmd_loop()})
endfunction

function! vimqq#cmdwatch#start(bot, messages)
  " strictly greater
  if g:vqq_autowarm_cmd_ms > 0 && !empty(a:messages)
      let s:messages = deepcopy(a:messages)
      let s:bot = a:bot
      let s:cmdwatch = 'on'
      let s:message_updated = v:false
      call timer_start(g:vqq_autowarm_cmd_ms, { -> s:_cmd_loop()})
  endif
endfunction

function! vimqq#cmdwatch#stop()
    let s:cmdwatch = 'off'
endfunction

" we'll call this when warmup is done, so next warmup is ok to send
function! vimqq#cmdwatch#next()
    call vimqq#log#debug('next warmup')
    if s:cmdwatch == 'on'
        let s:last_warmup_done = v:true
        call s:_check_cmd()
        call s:_send_warmup()
    endif
endfunction
