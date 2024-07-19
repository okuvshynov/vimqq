source vqq_module.vim
source utils.vim

let g:qq_anthropic_api_key = get(g:, 'qq_anthropic_api_key', $ANTHROPIC_API_KEY)

let g:qq_anthropic_model_name = get(g:, 'qq_anthropic_model_name', "claude-3-5-sonnet-20240620")

" auto-generated title max length
let s:qq_title_tokens  = 16

let g:vqq#AnthropicClient = {} 

function! g:vqq#AnthropicClient.new() dict
    " poor man inheritance 
    let l:instance = g:vqq#Base.new()
    call extend(l:instance, copy(self))

    let l:instance._model      = g:qq_anthropic_model_name
    let l:instance._api_key    = g:qq_anthropic_api_key
    let l:instance._max_tokens = g:qq_max_tokens

    let l:instance._reply_by_id = {}
    let l:instance._title_reply_by_id = {}

    return l:instance
endfunction

" {{{ private:

function! g:vqq#AnthropicClient._on_title_out(chat_id, msg) dict
    call add(self._title_reply_by_id[a:chat_id], a:msg)
endfunction

function g:vqq#AnthropicClient._on_title_close(chat_id) dict
    let l:response = json_decode(join(self._title_reply_by_id[a:chat_id], '\n'))
    let l:title  = l:response.content[0].text
    " we pretend it's one huge update
    call self.call_cb('title_done_cb', a:chat_id, title)
endfunction

function! g:vqq#AnthropicClient._on_out(chat_id, msg) dict
    call add(self._reply_by_id[a:chat_id], a:msg)
endfunction

function! g:vqq#AnthropicClient._on_err(chat_id, msg) dict
    " TODO logging
endfunction

function g:vqq#AnthropicClient._on_close(chat_id) dict
    let l:response = json_decode(join(self._reply_by_id[a:chat_id], '\n'))
    let l:message  = l:response.content[0].text
    " we pretend it's one huge update
    call self.call_cb('token_cb', a:chat_id, l:message)
    " and immediately done
    call self.call_cb('stream_done_cb', a:chat_id)
endfunction

function! g:vqq#AnthropicClient._send_query(req, job_conf) dict
    let l:json_req  = json_encode(a:req)
    let l:json_req  = substitute(l:json_req, "'", "'\\\\''", "g")

    let l:curl_cmd  = "curl -s -X POST 'https://api.anthropic.com/v1/messages'"
    let l:curl_cmd .= " -H 'Content-Type: application/json'"
    let l:curl_cmd .= " -H 'x-api-key: " . self._api_key . "'"
    let l:curl_cmd .= " -H 'anthropic-version: 2023-06-01'"
    let l:curl_cmd .= " -d '" . l:json_req . "'"

    call VQQKeepJob(job_start(['/bin/sh', '-c', l:curl_cmd], a:job_conf))
endfunction

function! g:vqq#AnthropicClient._format_messages(messages) dict
    let l:res = []
    for msg in a:messages
        call add (l:res, {'role': msg.role, 'content': msg.content})
    endfor
    return l:res
endfunction

" }}}

" {{{ public:

function! g:vqq#AnthropicClient.send_warmup(chat_id, messages) dict
  " we do nothing, as Anthropic API is stateless, no point in 
  " preparing anything
endfunction

function! g:vqq#AnthropicClient.send_chat(chat_id, messages) dict
    let req = {}
    let req.model      = self._model
    let req.messages   = self._format_messages(a:messages)
    let req.max_tokens = self._max_tokens
    let self._reply_by_id[a:chat_id] = []

    let l:job_conf = {
          \ 'out_cb'  : {channel, msg -> self._on_out(a:chat_id, msg)}, 
          \ 'err_cb'  : {channel, msg -> self._on_err(a:chat_id, msg)},
          \ 'close_cb': {channel      -> self._on_close(a:chat_id)}
    \ }

    call self._send_query(req, l:job_conf)
endfunction

" ask for a title we'll use. Uses first message in a chat
function! g:vqq#AnthropicClient.send_gen_title(chat_id, message_text) dict
    let req = {}
    let prompt = "Write a title with a few words summarizing the following paragraph. Reply only with title itself. Use no quotes around it.\n\n"
    let req.messages   = [{"role": "user", "content": prompt . a:message_text}]
    let req.max_tokens = s:qq_title_tokens
    let req.model      = self._model

    let self._title_reply_by_id[a:chat_id] = []

    let l:job_conf = {
          \ 'out_cb'  : {channel, msg -> self._on_title_out(a:chat_id, msg)},
          \ 'close_cb': {channel      -> self._on_title_close(a:chat_id)}
    \ }

    call self._send_query(req, l:job_conf)
endfunction

" }}}
