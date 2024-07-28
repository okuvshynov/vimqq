if exists('g:autoloaded_vimqq_utils')
    finish
endif
let g:autoloaded_vimqq_utils = 1

let s:n_jobs_cleanup = 32
let s:active_jobs    = []

function! s:_keep_job(job)
    let s:active_jobs += [a:job]
    if len(s:active_jobs) > s:n_jobs_cleanup
        for job in s:active_jobs[:]
            if job_info(job)['status'] == 'dead'
                call remove(s:active_jobs, index(s:active_jobs, job))
            endif
        endfor
    endif
endfunction

function! vimqq#jobs#start(command, config)
    let l:job = job_start(a:command, a:config)
    if job_status(l:job) == 'fail'
        call vimqq#log#error('Job ' . a:command . 'failed to start.')
        return v:false
    endif
    call s:_keep_job(l:job)
    return v:true
endfunction
