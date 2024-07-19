# vim-qna

### setup with sonnet API:

1. Put your API key to ```ANTHROPIC_API_KEY``` environment variable
2. Load vqna by e.g. adding 

```
source ~/projects/vim-qna/vqna.vim
```

to your vimrc file


### Local setup with llama.cpp server

1. get and build llama.cpp
2. download model
3. start server: 

```
./llama.cpp/llama-server --model ./llms/gguf/Meta-Llama-3-70B-Instruct-v2.Q8_0-00001-of-00003.gguf --chat-template llama3 --host 0.0.0.0
```

4. configure the endpoint in vimrc:

```
let g:vqna_local_addr = "http://your_m2_studio.local:8080/chat/completions"
```

Default is localhost:8080, so if you run llama.cpp server on the same machine you use vim you can skip this step.

5. Load vqna by e.g. adding 

```
source ~/projects/vim-qna/vqna.vim
```

to your vimrc file


## TODO

Let's keep input simple - we can only type the question itself in command line (not in the buffer) and the history will be displayed separately. What more complicated things do we need:
- [x] Command to show/hide history window
- [x] Saving chats locally
- [x] sessions support
- [x] work with llama.cpp chat
- [x] server status in chat window
- [x] appending to the history, so we can ask follow-up question. `:QQ something something` needs to append question to the current chat. 
- [x] creating new chats. `:QQN something something` would be new?
- [x] session selection/loading
- [x] session list
- [ ] change shortcuts, define commands the right way, now it is a mess
- [x] check what's up with cache reuse and \n\n token.
- [x] session dictionary
- [ ] deleting sessions.
- [x] generating title for chat
- [x] visual selection is incorrect
- [x] date/time of last message in chat selection
- [x] ordering in chat selection
- [x] navigating within chat session
- [x] encapsulate all access to session data. For all updates have callbacks from chat store, do not append anything directly.
- [x] refactor to something mvc-like (ui, db, client, main logic)
- [ ] prefetch on chat selection
- [ ] improve status line - show number of tokens, chat name and server addr? make configurable
- [ ] installation/distribution
- [ ] recording some feedback (e.g. good answer, bad answer, wrong answer, etc)

Later
- [ ] multi-agent support - chat with multiple bots
- [ ] code review. Ask to provide input without writing code itself. 

Maybe never
- [ ] integration with fzf
- [ ] use popup similar to fzf
