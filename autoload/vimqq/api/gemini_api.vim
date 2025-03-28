if exists('g:autoloaded_vimqq_api_gemini_module')
    finish
endif

let g:autoloaded_vimqq_api_gemini_module = 1

let g:vqq_gemini_api_key = get(g:, 'vqq_gemini_api_key', $GEMINI_API_KEY)

" TODO Need to cache more than just index
let g:vqq_gemini_cache_above = get(g:, 'vqq_gemini_cache_above', 5000)

let s:RATE_LIMIT_WAIT_S = 60

" config is unused for now
function! vimqq#api#gemini_api#new(conf = {}) abort
    let api = {}

    let api._base_url = get(a:conf, 'base_url', 'https://generativelanguage.googleapis.com')
    let api._req_id = 0
    let api._api_key = g:vqq_gemini_api_key
    let api._req_usages = {}
    let api._req_last_turn_usages = {}

    let api._builders = {}

    function! api._on_error(msg, params) dict
        call vimqq#log#error('job error')
    endfunction

    function! api._on_rate_limit(params) dict
        call s:SysMessage(
            \ 'warning',
            \ 'Reached rate limit. Waiting ' . s:RATE_LIMIT_WAIT_S . ' seconds before retry'
        \ )

        call timer_start(s:RATE_LIMIT_WAIT_S * 1000, { timer_id -> self.chat(a:params)})
    endfunction

    function! api._handle_error(error_json, params) dict
        " TODO: Implement error handling specific to Gemini API
        let err = string(a:error_json['error'])
        if get(a:error_json['error'], 'status', '') ==# 'RESOURCE_EXHAUSTED'
            call self._on_rate_limit(a:params)
            return
        endif
        call s:SysMessage('error', err)
        call vimqq#log#error(err)
    endfunction

    function! api._on_out(msg, params, req_id) dict
        let builder = self._builders[a:req_id]
        call builder.part(a:msg)
    endfunction

    function! api._on_close(params, req_id) dict
        let builder = self._builders[a:req_id]
        call builder.close()
        call self._cleanup_req_id(a:req_id)
    endfunction
    
    function! api._cleanup_req_id(req_id) dict
        " Clean up resources for this req_id to avoid memory leaks
        if has_key(self._builders, a:req_id)
            unlet self._builders[a:req_id]
        endif
        if has_key(self._req_usages, a:req_id)
            unlet self._req_usages[a:req_id]
        endif
        if has_key(self._req_last_turn_usages, a:req_id)
            unlet self._req_last_turn_usages[a:req_id]
        endif
    endfunction

    function! api.chat(params) dict
        " Main function to send chat requests to Gemini API
        let req = vimqq#api#gemini_adapter#run(a:params)
        
        " TODO: Implement Gemini-specific request handling here
        
        let req_id = self._req_id
        let self._req_id = self._req_id + 1

        let self._builders[req_id] = vimqq#api#gemini_builder#plain(a:params)
        let job_conf = {
        \   'out_cb': {channel, d -> self._on_out(d, a:params, req_id)},
        \   'err_cb': {channel, d -> self._on_error(d, a:params)},
        \   'close_cb': {channel -> self._on_close(a:params, req_id)}
        \ }

        let json_req = json_encode(req)
        call vimqq#log#debug('JSON_REQ: ' . json_req)
        
        " Gemini API uses API key as a URL parameter
        let headers = {
            \ 'Content-Type': 'application/json'
        \ }
        
        " TODO: Adjust URL and headers for Gemini API
        " Note: Gemini typically uses ?key=API_KEY in the URL
        return vimqq#platform#http#post(
            \ self._base_url . '/v1beta/models/' . req.model . ':generateContent?key=' . self._api_key,
            \ headers,
            \ json_req,
            \ job_conf)
    endfunction

    return api
endfunction
