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

function! s:ParseRange(cmdline)
  let l:result = {'start': '', 'end': '', 'cmd': ''}
  
  " TODO: This needs to be tested well
  "  - doesn't work for % (entire file)
  let l:range_regex = '^\%('
        \ . '\%(\d\+\|\.\|\$\|\%([+-]\d*\)\|'
        \ . '\/[^/]\\{-}\/\|?[^?]\\{-}?\|'
        \ . '''[[:alpha:]<>]\)'
        \ . '\%([-+]\d*\)*'
        \ . '\)'
        \ . '\%([,;]'
        \ . '\%(\d\+\|\.\|\$\|\%([+-]\d*\)\|'
        \ . '\/[^/]\\{-}\/\|?[^?]\\{-}?\|'
        \ . '''[[:alpha:]<>]\)'
        \ . '\%([-+]\d*\)*'
        \ . '\)*'


  let l:cmdline = a:cmdline
  let l:match = matchstr(l:cmdline, l:range_regex)
  
  if !empty(l:match)
    " Split range into start and end if comma exists
    let l:range_parts = split(l:match, '[,;]')
    let l:result.start = get(l:range_parts, 0, '')
    let l:result.end = get(l:range_parts, 1, '')
    
    " Get the actual command after the range
    let l:result.cmd = strpart(l:cmdline, len(l:match))
  else
    let l:result.cmd = l:cmdline
  endif
  
  return l:result
endfunction


function! s:parse_command_line(cmd)
    call vimqq#log#debug(a:cmd)
    if a:cmd =~# '^Q\s'
        let args = a:cmd[2:]
        let parsed = vimqq#parser#q(args)
        call vimqq#log#debug(string(parsed))
        return parsed
    endif
    if a:cmd =~# '^QQ\s'
        let args = a:cmd[3:]
        let parsed = vimqq#parser#qq(args)
        call vimqq#log#debug(string(parsed))
        return parsed
    endif
    return v:null
endfunction

" Timer callback function
function! s:CheckCommandLine(timer_id)
    if mode() ==# 'c'  " Check if we're in command mode
        let cmd = s:GetCurrentCommand()
        let parsed = s:ParseRange(cmd)
        let parsed_cmd = s:parse_command_line(parsed.cmd)
        if parsed_cmd is v:null
            return
        endif
        if s:warmup_in_progress 
            call vimqq#log#debug('not issuing second warmup')
            return
        endif
        let s:warmup_in_progress = v:true
        call vimqq#main#send_warmup(parsed_cmd.ctx_options, parsed_cmd.new_chat, parsed_cmd.message)
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
    let l:w = {}

    let l:w._bots = []
    let l:w._db = a:db
    for bot in a:bots.bots()
        if bot.do_autowarm()
            call add(l:w._bots, bot)
        endif
    endfor

    function! l:w.handle_event(event, args) dict
    endfunction

    function! l:w.handle_event(event, args)
        if a:event == 'warmup_done'
            " TODO: we might be able to notify and immediately kick off the
            " next one
            let s:warmup_in_progress = v:false
        endif
        if a:event == 'title_saved' || a:event == 'chat_selected'
            let chat_id = a:args['chat_id']
            if !self._db.chat_exists(chat_id)
                call vimqq#log#info("warmup on non-existent chat.")
                return
            endif
            let messages = self._db.get_messages(chat_id)
            for bot in self._bots
                call vimqq#metrics#inc(bot.name() . ".chat_warmups" )
                call bot.send_warmup(messages)
            endfor
        endif
    endfunction

    return l:w
endfunction

augroup VQQCommandLinePrefetch
  autocmd!
  " Start timer when entering command line mode
  autocmd CmdlineEnter : call s:StartCommandTimer()
  " Stop timer when leaving command line mode
  autocmd CmdlineLeave : call timer_stop(s:check_timer)
augroup END
