if exists('g:autoloaded_vimqq_autowarm')
    finish
endif

let g:autoloaded_vimqq_autowarm = 1

" The assumption is we have 1 warmup query at a time. Might need to 
" revisit.

" if we sent warmup query, start timer 
let g:vqq_autowarm_cmd_ms = get(g:, 'vqq_autowarm_cmd_ms', 500)

" in llama.cpp server 
" on MacOS model might be getting offloaded even if we use mlock. 
" Thus, we have an option to keep sending warmup queries even if message
" hasn't changed
" TODO: should this be per bot? 
let g:vqq_autowarm_same_msg = get(g:, 'vqq_autowarm_same_msg', v:true)

let s:autowarm = 'off'
" we use this for warmup
let s:messages = []
let s:bot = -1
let s:message_updated = v:false
let s:last_warmup_done = v:false

function! s:_send_warmup()
    let l:message_flag = s:message_updated || g:vqq_autowarm_same_msg
    if s:autowarm == 'on' && l:message_flag && s:last_warmup_done
        let s:message_updated = v:false
        let s:last_warmup_done = v:false
        call vimqq#log#debug('sending next warmup')
        call s:bot.send_warmup(s:messages)
    endif
endfunction

function! s:_check_cmd()
    " TODO: do we need to check that mode() == 'c'?
    if s:autowarm == 'off' || empty(s:messages)
        let s:autowarm = 'off'
        let s:messages = []
        return
    endif

    let cmdline = getcmdline()

    call vimqq#log#debug('warmup cmdline: ' . cmdline)
    
    let l:tag = '@' . s:bot.name() . ' '
    " we assume that cmdline is 'some options here {l:tag} message'

    let idx = stridx(cmdline, l:tag)
    if idx == -1
        let s:autowarm = 'off'
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

function! vimqq#autowarm#new() abort
    let l:aw = {}

    function l:aw.start(bot, messages) dict
      if g:vqq_autowarm_cmd_ms > 0 && !empty(a:messages)
          let s:messages = deepcopy(a:messages)
          let s:bot = a:bot
          let s:autowarm = 'on'
          let s:message_updated = v:false
          call timer_start(g:vqq_autowarm_cmd_ms, { -> s:_cmd_loop()})
      endif
    endfunction

    function! l:aw.stop() dict
        let s:autowarm = 'off'
    endfunction

    " we'll call this when warmup is done, so next warmup is ok to send
    function! l:aw.next() dict
        call vimqq#log#debug('next warmup')
        if s:autowarm == 'on'
            let s:last_warmup_done = v:true
            call s:_check_cmd()
            call s:_send_warmup()
        endif
    endfunction

    function! l:aw.handle_event(event, args) dict
        if a:event == 'warmup_done'
            call self.next()
        endif
    endfunction

    return l:aw
endfunction
