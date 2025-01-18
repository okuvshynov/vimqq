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

let s:check_timer = -1
let s:warmup_in_progress = v:false

function! s:GetCurrentCommand()
  if getcmdtype() ==# ':'
    return getcmdline()
  endif
  return ''
endfunction

let s:current_message = ''
function! s:ranged_warmup(new_chat) range
    let lines = getline(a:firstline, a:lastline)
    let context = join(lines, '\n')
    call vimqq#main#send_warmup(a:new_chat, s:current_message, context)
endfunction

function! s:parse_command_line(cmd)
    " Q doesn't receive range. This is the only way to invoke it.
    if a:cmd =~# '^QQ\s'
        let message = a:cmd[2:]
        call vimqq#main#send_warmup(v:false, message)
        return v:true
    endif

    if a:cmd =~# '^QQN\s'
        let message = a:cmd[3:]
        call vimqq#main#send_warmup(v:true, message)
        return v:true
    endif

    let qq_pattern = '\v^(.+)QQ\s+(.*)$'
    let matches = matchlist(a:cmd, qq_pattern)
    if len(matches) > 0
        let range = matches[1]
        let s:current_message = matches[2]
        try
            execute range . 'call s:ranged_warmup(v:false)'
            return v:true
        catch
            return v:false
        endtry
    endif

    let qq_pattern = '\v^(.+)QQN\s+(.*)$'
    let matches = matchlist(a:cmd, qq_pattern)
    if len(matches) > 0
        let range = matches[1]
        let s:current_message = matches[2]
        try
            execute range . 'call s:ranged_warmup(v:true)'
            return v:true
        catch
            return v:false
        endtry
    endif

    return v:false
endfunction

" Timer callback function
function! s:CheckCommandLine(timer_id)
    if mode() ==# 'c'  " Check if we're in command mode
        if s:warmup_in_progress 
            call vimqq#log#debug('not issuing second warmup')
            return
        endif
        let cmd = s:GetCurrentCommand()
        " TODO: here we are actually missing the range.
        let s:warmup_in_progress = s:parse_command_line(cmd)
    endif
endfunction

function! s:StartCommandTimer()
  " Stop existing timer if any
  if s:check_timer != -1
    call timer_stop(s:check_timer)
  endif
  
  " Start new timer that runs every 500ms
  let s:check_timer = timer_start(500, function('s:CheckCommandLine'), 
        \ {'repeat': -1})  " -1 means repeat indefinitely
endfunction

function! vimqq#warmup#new(bots, db) abort
    let w = {}

    let w._bots = []
    let w._db = a:db
    for bot in a:bots.bots()
        if bot.do_autowarm()
            call add(w._bots, bot)
        endif
    endfor

    function! w.handle_event(event, args) dict
        if a:event ==# 'warmup_done'
            " TODO: we might be able to notify and immediately kick off the
            " next one
            let s:warmup_in_progress = v:false
        endif
        if a:event ==# 'title_saved' || a:event ==# 'chat_selected'
            let chat_id = a:args['chat_id']
            if !self._db.chat_exists(chat_id)
                call vimqq#log#info("warmup on non-existent chat.")
                return
            endif
            let messages = self._db.get_messages(chat_id)
            for bot in self._bots
                call bot.send_warmup(messages)
            endfor
        endif
    endfunction

    return w
endfunction

augroup VQQCommandLinePrefetch
  autocmd!
  " Start timer when entering command line mode
  autocmd CmdlineEnter : call s:StartCommandTimer()
  " Stop timer when leaving command line mode
  autocmd CmdlineLeave : call timer_stop(s:check_timer)
augroup END

