if exists('g:autoloaded_vimqq_warmup')
    finish
endif

let g:autoloaded_vimqq_warmup = 1

" There are two separate 'warmups'
" being done here:
"  - warmup when we started typing something matching vimqq command
"  - warmup when we opened old chat or title was generated
"  These two situations are handled differently and we need to unify this 
"  a little + add configuration (per bot?)

" TODO(state)
let s:warmup_timer = -1
let s:warmup_in_progress = v:false
let s:current_message = ''

let s:WARMUP_INTERVAL_MS = 500

function! s:ranged_warmup(new_chat) range
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    let s:warmup_in_progress = vimqq#main#send_warmup(a:new_chat, s:current_message, context)
endfunction

" public for unit testing
function! vimqq#warmup#parse(cmd)
    if a:cmd =~# '^QQ\s'
        let message = a:cmd[3:]
        let s:warmup_in_progress = vimqq#main#send_warmup(v:false, message)
        return
    endif

    if a:cmd =~# '^QQN\s'
        let message = a:cmd[4:]
        let s:warmup_in_progress = vimqq#main#send_warmup(v:true, message)
        return
    endif

    let qq_pattern = '\v^(.+)QQ\s+(.*)$'
    let matches = matchlist(a:cmd, qq_pattern)
    if len(matches) > 0
        let range = matches[1]
        let s:current_message = matches[2]
        try
            execute range . 'call s:ranged_warmup(v:false)'
        catch
        endtry
    endif

    let qq_pattern = '\v^(.+)QQN\s+(.*)$'
    let matches = matchlist(a:cmd, qq_pattern)
    if len(matches) > 0
        let range = matches[1]
        let s:current_message = matches[2]
        try
            execute range . 'call s:ranged_warmup(v:true)'
        catch
        endtry
    endif
endfunction

" Timer callback function
function! s:check_command_line(timer_id)
    if mode() ==# 'c'  " Check if we're in command mode
        if s:warmup_in_progress 
            call vimqq#log#debug('not issuing second warmup')
            return
        endif
        if getcmdtype() ==# ':'
            let cmdline = getcmdline()
            call vimqq#warmup#parse(cmdline)
            call vimqq#log#debug('warmup: [' . cmdline . '] ' . string(s:warmup_in_progress))
        endif
    endif
endfunction

function! s:start_command_timer()
    " Stop existing timer if any
    if s:warmup_timer != -1
        call timer_stop(s:warmup_timer)
    endif

    let s:warmup_timer = timer_start(
        \ s:WARMUP_INTERVAL_MS, 
        \ function('s:check_command_line'), 
        \ {'repeat': -1}
    \)  " -1 means repeat indefinitely
endfunction

function! vimqq#warmup#start() abort
    call vimqq#log#info('autoloaded, monitoring command line.')
endfunction

function! vimqq#warmup#done() abort
    let s:warmup_in_progress = v:false
endfunction

augroup VQQCommandLinePrefetch
    autocmd!
    " Start timer when entering command line mode
    autocmd CmdlineEnter : call s:start_command_timer()
    " Stop timer when leaving command line mode
    autocmd CmdlineLeave : call timer_stop(s:warmup_timer)
augroup END

