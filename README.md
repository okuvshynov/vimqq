# vim quick question (vim-qq)

vim ai chat plugin with the following focus areas:
* communication with local models and paid APIs within the same chat session;
* explanation/education/code review rather than code completion, infill, generation, etc. Reading and understanding code is harder and more time-consuming part compared to writing;

LLMs are still not too good at generating complex code, especially if the change is spread across many files in huge repo, which is precisely what many important code changes are. At the same time, LLMs are reasonably good at trying to explain what the code is trying to accomplish, pretty good at suggesting alternatives/cleaner ways/already existing tools to achieve something, etc. I view it as having a hybrid coach/assistant model, where, while an athlete or an executive might be 'better' than coach (same as humans are better software engineers than LLMs), coach can provide useful, unique and valuable insights. 

The expectations here are:
* It won't write much code for me;
* It will help me read/understand code faster;
* It will help me write a little bit better code.

Key features:
* use both claude/local llama.cpp within same chat session. Can pick on multiple bots to pick on based on problem complexity/cost/capabilities/etc. Multi-backend support was implemented to be able to experiment on different local/closed models. The idea is to, for example, ask Sonnet 3.5 a question, get some options/alternatives and then continue the conversation with a different bot (maybe haiku, maybe local llama3, etc.). We'll see config below having 2 local models and one claude model configured.
* streaming response from llama.cpp server and show it in vim right away, token by token. This is important for large models running locally - llama3 70B gets ~8 tps on m2 ultra, which is close to typical human reading rate, so we can just read as the reply is getting produced.
* easily share context based on visual selection in vim. Be able to select lines, hit a hotkey and ask 'what is it doing?', 'what might be corner cases here?', 'how would you modernize this code?', 'how would you test this code?'.
* kv cache warmup to save on local prompt processing time. We can warmup KV cache for the lengthy multiple-turn chat session or a large code selection before we finished typing the question, thus amortizing the prompt processing cost. Hit hotkey, selection/previous messages are already being worked on in parallel while you are typing the question.

Claude is stateles and will charge per token in both the input and the output, and each message will send/process all the tokens again as an input, so if you keep chatting you get O(n^2) cost. For example, if you send a message with 100 tokens and received an answer with 1000 tokens, and did that 10 times within same chat session, you'll pay `1000 * 10 = 10k` tokens of output and `(55*100 + 45*1000) = ~50k` tokens of input. It costs less than a dollar (~$0.30), but it can still add up. We can also expect ~5x cost for next opus model likely coming later this year.

## requirements

* Vim 8.2+
* llama.cpp if planning to use local models
* anthropic API subscription if planning to use claude family of models

## Installation

Get the plugin:
```
git clone https://github.com/okuvshynov/vimqq.git ~/.vim/pack/plugins/start/vimqq

```

If planning to use local models, get llama.cpp server

```
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make -j 16
```

If planning to use claude API, get API key and put it in `$ANTHROPIC_API_KEY` environment variable

Configure the bots in vimrc
```
" Example commands to start the server:
" ./llama.cpp/llama-server --model ./llms/gguf/llama3.70b.q8.inst.gguf --chat-template llama3 --host 0.0.0.0 --top_p 0.0 --top_k 1 --port 8080
" ./llama.cpp/llama-server --model ./llms/gguf/llama3.8b.q8.inst.gguf --chat-template llama3 --host 0.0.0.0 --top_p 0.0 --top_k 1 --port 8088
let g:vqq_llama_servers = [
      \  {'bot_name': 'llama8', 'addr': 'http://studio.local:8088'},
      \  {'bot_name': 'llama70', 'addr': 'http://studio.local:8080'}
\]

" optional parameters for llama server config:
"  - max_tokens: how many tokens to generate. default: 1024
"  - title_tokens: how many tokens to generate to get title. default: 16
"  - healthcheck_ms: how often to issue healthcheck query. default: 10000 (=10s)


" -----------------------------------------------------------------------------
" Anthropic models configuration

let g:vqq_claude_models = [
      \  {'bot_name': 'sonnet', 'model': 'claude-3-5-sonnet-20240620'}
\]

" optional parameters for claude config:
"  - max_tokens: how many tokens to generate. default: 1024
"  - title_tokens: how many tokens to generate to get title. default: 16
" API key. default is environment variable $ANTHROPIC_API_KEY
" let g:vqq_claude_api_key = 
```

Plugin defines only commands, no key bindings, but here's an example. You can check [demo_config.vim](demo_config.vim) for an example of 'how my personal config in vimrc might look like'.

```
function! VQQWarmup(bot)
    execute 'VQQWarmCtx ' . a:bot 
    call feedkeys(":'<,'>VQQSendCtx " . a:bot . " ", 'n')
endfunction

function! VQQWarmupNew(bot)
    execute 'VQQWarmNewCtx ' . a:bot 
    call feedkeys(":'<,'>VQQSendNewCtx " . a:bot . " ", 'n')
endfunction

function! VQQQuery(bot)
    call feedkeys(":VQQSend " . a:bot . " ", 'n')
endfunction

function! VQQQueryNew(bot)
    call feedkeys(":VQQSendNew " . a:bot . " ", 'n')
endfunction

" [w]armup llama70b
xnoremap <silent> <leader>w :<C-u>call VQQWarmup('@llama70')<cr>
" [w]armup new chat llama70b
xnoremap <silent> <leader>ww :<C-u>call VQQWarmupNew('@llama70')<cr>

" [q]uery llama70b
nnoremap <silent> <leader>q :<C-u>call VQQQuery('@llama70')<cr>
nnoremap <silent> <leader>qq :<C-u>call VQQQueryNew('@llama70')<cr>

" query [s]onnet
nnoremap <silent> <leader>s :<C-u>call VQQQuery('@sonnet')<cr>
nnoremap <silent> <leader>ss :<C-u>call VQQQueryNew('@sonnet')<cr>

" [C]hat list
nnoremap <silent> <leader>ll :<C-u>execute 'VQQList'<cr>

let g:vqq_warmup_on_chat_open = ['llama70']

```

Example of what you can do with this config (assuming leader is `\`) : 
1. Select some text in vim in visual mode
2. Press `\w`
3. warmup request will be sent to llama.cpp server preparing the cache with system prompt, and part of your message with the code
4. focus will automatically move to command-line and prefilled with the right command, you can start typing your question there.
5. After you hit enter (`<cr>`) the final request will be sent and you should start seeing reply being streamed to vim buffer

It is easy to add custom mappings which would do more specific things. For example,

```
" [R]eview code
xnoremap <silent> <leader>R :<C-u>execute "'<,'>VQQSendNewCtx @llama70 please review the code and share suggestions for improvement."<cr>
```

Now you can do the following:
1. Select some text in vim in visual mode
2. Press `\R`
3. Both the code and your message will be sent to llama server and you should start seeing the reply being updated.



https://github.com/user-attachments/assets/ead4c5a3-c441-4fab-9607-5f5f66614442




## TODO

- [ ] deleting chats
- [ ] doc/help

Later

- [ ] recording some feedback (e.g. good answer, bad answer, wrong answer, etc)

Maybe never
- [ ] integration with fzf
- [ ] use popup similar to fzf

old completed:
- [x] generating title for chat
- [x] visual selection is incorrect
- [x] date/time of last message in chat selection
- [x] ordering in chat selection
- [x] navigating within chat session
- [x] encapsulate all access to session data. For all updates have callbacks from chat store, do not append anything directly.
- [x] refactor to something mvc-like (ui, db, client, main logic)
- [x] prefetch on chat selection
- [x] improve status line - show number of tokens, botname
- [x] installation/distribution/correct directory structure
- [x] multi-agent support - chat with multiple bots
- [x] Command to show/hide history window
- [x] Saving chats locally
- [x] sessions support
- [x] work with llama.cpp chat
- [x] server status in chat window
- [x] appending to the history, so we can ask follow-up question. `:QQ something something` needs to append question to the current chat. 
- [x] creating new chats. `:QQN something something` would be new?
- [x] session selection/loading
- [x] session list
- [x] change shortcuts, define commands the right way, now it is a mess
- [x] check what's up with cache reuse and \n\n token.
- [x] session dictionary
- [x] code review. Ask to provide input without writing code itself. 
