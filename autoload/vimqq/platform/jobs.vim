if exists('g:autoloaded_vimqq_utils')
    finish
endif
let g:autoloaded_vimqq_utils = 1

let s:N_JOBS_CLEANUP = 32
let s:active_jobs    = []

function! s:is_empty_list(v)
    if type(a:v) == type([])
        if len(a:v) == 1 && a:v[0] ==# ''
            return v:true
        else
            return v:false
        endif
    else
        return v:false
    endif
endfunction

function! s:keep_job(job)
    let s:active_jobs += [a:job]
    if len(s:active_jobs) > s:N_JOBS_CLEANUP
        for job in s:active_jobs[:]
            if job_info(job)['status'] ==# 'dead'
                call remove(s:active_jobs, index(s:active_jobs, job))
            endif
        endfor
    endif
endfunction

" async job supporting both vim and nvim
"   - adapting callbacks.
"   - using different job_start/jobstart
"
" vim callbacks are:
"   out_cb : {channel, msg -> }
"   err_cb : {channel, msg -> }
"   close_cb : {channel -> }
"   exit_cb : {job_id, status -> }

function! vimqq#platform#jobs#start(command, config)
    if has('nvim')
        return s:start_nvim(a:command, a:config)
    endif
    let OnJob = v:null
    if has_key(a:config, 'on_job')
        let OnJob = a:config['on_job']
        call remove(a:config, 'on_job')
    endif

    let job = job_start(a:command, a:config)

    if OnJob isnot v:null
        call OnJob(job)
    endif
    if job_status(job) ==# 'fail'
        call vimqq#log#error('Job ' . string(a:command) . 'failed to start.')
        return v:false
    endif
    call s:keep_job(job)
    return v:true
endfunction

function! s:start_nvim(command, config)
    " need to transform config
    let conf = {}
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

    let conf["on_stdout"] = {c,d,n -> s:is_empty_list(d) ? OnClose(c,d,n) : OnOut(c,d,n)}
    if has_key(a:config, "err_cb")
        let StderrCb = a:config["err_cb"]
        let conf["on_stderr"] = {c, d, n -> s:is_empty_list(d) ? {c,d,n -> {}} : StderrCb(c, join(d, "\n"))}
    endif
    if has_key(a:config, "exit_cb")
        let ExitCb = a:config["exit_cb"]
        let conf["on_exit"] = {channel, status, name -> ExitCb(channel, status)}
    endif

    let job = jobstart(a:command, conf)
    if job <= 0
        return v:false
    endif
    return v:true
endfunction
