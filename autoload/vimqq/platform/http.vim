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
    let headers_file = tempname()
    let curl_args = ['curl', '-s', '--no-buffer', '-X', 'POST', '-D', headers_file]
    call vimqq#log#debug('http_headers: ' . headers_file)
    
    " Add URL
    call add(curl_args, a:url)
    
    " Add headers
    for [key, value] in items(a:headers)
        call add(curl_args, '-H')
        call add(curl_args, key . ': ' . value)
    endfor
    
    " Add body
    call add(curl_args, '-d')
    call add(curl_args, a:body)
    
    return vimqq#platform#jobs#start(curl_args, a:job_conf)
endfunction

" Send GET request
" Args:
"   url: string - URL to send request to
"   options: list - additional curl options 
"   job_conf: dict - job configuration for response handling
function! vimqq#platform#http#get(url, options, job_conf) abort
    let curl_cmd = ["curl"] + a:options + [a:url]
    return vimqq#platform#jobs#start(curl_cmd, a:job_conf)
endfunction
