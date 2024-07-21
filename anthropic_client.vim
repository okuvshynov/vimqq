source vqq_module.vim
source utils.vim

let g:vqq_claude_api_key = get(g:, 'vqq_claude_api_key', $ANTHROPIC_API_KEY)

let s:default_conf = {
  \ 'title_tokens'   : 16,
  \ 'max_tokens'     : 1024,
  \ 'bot_name'       : 'Claude',
\ }

let g:vqq#ClaudeClient = {} 

function! g:vqq#ClaudeClient.new(config = {}) dict
    " poor man inheritance 
    let l:instance = g:vqq#Base.new()
    call extend(l:instance, copy(self))

    let l:instance._conf = deepcopy(s:default_conf)
    call extend(l:instance._conf, a:config)

    let l:instance._api_key = g:vqq_claude_api_key

    let l:instance._reply_by_id = {}
    let l:instance._title_reply_by_id = {}

    return l:instance
endfunction

" {{{ private:

function! g:vqq#ClaudeClient._on_title_out(chat_id, msg) dict
    call add(self._title_reply_by_id[a:chat_id], a:msg)
endfunction

function g:vqq#ClaudeClient._on_title_close(chat_id) dict
    let l:response = json_decode(join(self._title_reply_by_id[a:chat_id], '\n'))
    let l:title  = l:response.content[0].text
    " we pretend it's one huge update
    call self.call_cb('title_done_cb', a:chat_id, title)
endfunction

function! g:vqq#ClaudeClient._on_out(chat_id, msg) dict
    call add(self._reply_by_id[a:chat_id], a:msg)
endfunction

function! g:vqq#ClaudeClient._on_err(chat_id, msg) dict
    " TODO logging (or status callback?)
endfunction

function g:vqq#ClaudeClient._on_close(chat_id) dict
    let l:response = json_decode(join(self._reply_by_id[a:chat_id], '\n'))
    let l:message  = l:response.content[0].text
    " we pretend it's one huge update
    call self.call_cb('token_cb', a:chat_id, l:message)
    " and immediately done
    call self.call_cb('stream_done_cb', a:chat_id, self)
endfunction

function! g:vqq#ClaudeClient._send_query(req, job_conf) dict
    let l:json_req  = json_encode(a:req)
    let l:json_req  = substitute(l:json_req, "'", "'\\\\''", "g")

    let l:curl_cmd  = "curl -s -X POST 'https://api.anthropic.com/v1/messages'"
    let l:curl_cmd .= " -H 'Content-Type: application/json'"
    let l:curl_cmd .= " -H 'x-api-key: " . self._api_key . "'"
    let l:curl_cmd .= " -H 'anthropic-version: 2023-06-01'"
    let l:curl_cmd .= " -d '" . l:json_req . "'"

    call VQQKeepJob(job_start(['/bin/sh', '-c', l:curl_cmd], a:job_conf))
endfunction

function! g:vqq#ClaudeClient._format_messages(messages) dict
    let l:res = []
    for msg in a:messages
        call add (l:res, {'role': msg.role, 'content': msg.content})
    endfor
    return l:res
endfunction

" }}}

" {{{ public:

function! g:vqq#ClaudeClient.name() dict
    return self._conf.bot_name
endfunction

function! g:vqq#ClaudeClient.send_warmup(chat_id, messages) dict
  " we do nothing, as Claude API is stateless, no point in 
  " preparing anything
endfunction

function! g:vqq#ClaudeClient.send_chat(chat_id, messages) dict
    let req = {}
    let req.model      = self._conf.model
    let req.messages   = self._format_messages(a:messages)
    let req.max_tokens = self._conf.max_tokens
    let self._reply_by_id[a:chat_id] = []

    let l:job_conf = {
          \ 'out_cb'  : {channel, msg -> self._on_out(a:chat_id, msg)}, 
          \ 'err_cb'  : {channel, msg -> self._on_err(a:chat_id, msg)},
          \ 'close_cb': {channel      -> self._on_close(a:chat_id)}
    \ }

    call self._send_query(req, l:job_conf)
endfunction

" ask for a title we'll use. Uses first message in a chat
function! g:vqq#ClaudeClient.send_gen_title(chat_id, message_text) dict
    let req = {}
    let prompt = "Write a title with a few words summarizing the following paragraph. Reply only with title itself. Use no quotes around it.\n\n"
    let req.messages   = [{"role": "user", "content": prompt . a:message_text}]
    let req.max_tokens = self._conf.title_tokens
    let req.model      = self._conf.model

    let self._title_reply_by_id[a:chat_id] = []

    let l:job_conf = {
          \ 'out_cb'  : {channel, msg -> self._on_title_out(a:chat_id, msg)},
          \ 'close_cb': {channel      -> self._on_title_close(a:chat_id)}
    \ }

    call self._send_query(req, l:job_conf)
endfunction

" }}}
