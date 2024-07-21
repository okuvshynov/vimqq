# vim quick question (vim-qq)

Key features:
* use both Sonnet/local llama.cpp within same chat session. Can have multiple bots to pick on for complexity/pricing/capabilities
* streaming text to vim
* easily share context based on visual selection in vim
* kv cache warmup to save on local prompt processing time


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
- [x] multi-agent support - chat with multiple bots

Later
- [ ] code review. Ask to provide input without writing code itself. 
- [ ] recording some feedback (e.g. good answer, bad answer, wrong answer, etc)

Maybe never
- [ ] integration with fzf
- [ ] use popup similar to fzf
