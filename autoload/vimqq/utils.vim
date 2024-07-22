if exists('g:autoloaded_vimqq_utils')
    finish
endif

let g:autoloaded_vimqq_utils = 1

let s:n_jobs_cleanup = 32
let s:active_jobs    = []

" async jobs management
function! vimqq#utils#keep_job(job)
    let s:active_jobs += [a:job]
    if len(s:active_jobs) > s:n_jobs_cleanup
        for job in s:active_jobs[:]
            if job_info(job)['status'] == 'dead'
                call remove(s:active_jobs, index(s:active_jobs, job))
            endif
        endfor
    endif
endfunction
