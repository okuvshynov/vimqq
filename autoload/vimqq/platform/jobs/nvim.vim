if exists('g:autoloaded_vimqq_platform_jobs_nvim')
    finish
endif
let g:autoloaded_vimqq_platform_jobs_nvim = 1

function! s:_is_empty_list(v)
    if type(a:v) == type([])
        if len(a:v) == 1 && a:v[0] == ''
            return v:true
        else
            return v:false
        endif
    else
        return v:false
    endif
endfunction

function! vimqq#platform#jobs#nvim#start(command, config)
    let l:conf = {}
    let OnOut = {c,d,n -> {}}
    let OnClose = {c,d,n -> {}}
    if has_key(a:config, "out_cb")
        let StdoutCb = a:config["out_cb"]
        let OnOut = {c, d, n -> StdoutCb(c, join(d, "\n"))}
    endif
    if has_key(a:config, "close_cb")
        let CloseCb = a:config["close_cb"]
        let OnClose = {c, d, n -> CloseCb(c)}
    endif

    let l:conf["on_stdout"] = {c,d,n -> s:_is_empty_list(d) ? OnClose(c,d,n) : OnOut(c,d,n)}
    if has_key(a:config, "err_cb")
        let StderrCb = a:config["err_cb"]
        let l:conf["on_stderr"] = {c, d, n -> s:_is_empty_list(d) ? {c,d,n -> {}} : StderrCb(c, join(d, "\n"))}
    endif
    if has_key(a:config, "exit_cb")
        let ExitCb = a:config["exit_cb"]
        let l:conf["on_exit"] = {channel, status, name -> ExitCb(channel, status)}
    endif

    let job = jobstart(a:command, l:conf)
    if job <= 0
        return v:false
    endif
    return v:true
endfunction