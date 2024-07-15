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
- [ ] sessions support
- [ ] work with llama.cpp chat
- [ ] server status in chat window
- [x] appending to the history, so we can ask follow-up question. `:QQ something something` needs to append question to the current chat. 
- [x] creating new chats. `:QQN something something` would be new?
- [ ] session selection, integration with fzf
- [ ] multi-agent support - chat with multiple bots
- [ ] change shortcuts, define commands the right way
- [ ] code review. Ask to provide input without writing code itself. 
- [ ] check what's with cache reuse and \n\n token.
