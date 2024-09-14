if exists('g:autoloaded_vimqq_cmdwatch')
    finish
endif

let g:autoloaded_vimqq_cmdwatch = 1

" TODO: we need to rename this to 'warmup something'

" if we sent warmup query, start timer 
let g:vqq_autowarm_cmd_ms = get(g:, 'vqq_autowarm_cmd_ms', 500)
" on MacOS model might be getting offloaded even if we use mlock. 
" thus, we have an option to keep sending warmup queries even if message
" hasn't changed
let g:vqq_autowarm_same_msg = get(g:, 'vqq_autowarm_same_msg', v:true)

let s:cmdwatch = 'off'
" we use this for warmup
let s:messages = []
let s:bot = -1
let s:message_updated = v:false
let s:last_warmup_done = v:false

function! s:_send_warmup()
    let l:message_flag = s:message_updated || g:vqq_autowarm_same_msg
    if s:cmdwatch == 'on' && l:message_flag && s:last_warmup_done
        let s:message_updated = v:false
        let s:last_warmup_done = v:false
        call vimqq#log#debug('sending next warmup')
        call s:bot.send_warmup(s:messages)
    endif
endfunction

function! s:_check_cmd()
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
