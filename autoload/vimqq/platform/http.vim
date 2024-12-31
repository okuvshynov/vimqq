" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_http_module')
    finish
endif

let g:autoloaded_vimqq_http_module = 1

" Send POST request
" Args:
"   url: string - URL to send request to
"   headers: dict - request headers
"   body: string - request body (JSON)
"   job_conf: dict - job configuration for response handling
function! vimqq#platform#http#post(url, headers, body, job_conf) abort
    let l:json_req = substitute(a:body, "'", "'\\\\''", "g")
    
    let l:curl_cmd = "curl -s --no-buffer -X POST '" . a:url . "'"
    for [key, value] in items(a:headers)
        let l:curl_cmd .= " -H '" . key . ": " . value . "'"
    endfor
    let l:curl_cmd .= " -d '" . l:json_req . "'"

    return vimqq#platform#jobs#start(['/bin/sh', '-c', l:curl_cmd], a:job_conf)
endfunction

" Send GET request
" Args:
"   url: string - URL to send request to
"   options: list - additional curl options 
"   job_conf: dict - job configuration for response handling
function! vimqq#platform#http#get(url, options, job_conf) abort
    let l:curl_cmd = ["curl"] + a:options + [a:url]
    return vimqq#platform#jobs#start(l:curl_cmd, a:job_conf)
endfunction
