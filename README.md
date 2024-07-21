# vim quick question (vim-qq)

Motivation:
* Typically good engineer spends much more time reading code than writing code. The main use-case here was to help understand what's going on, not to make LLM write quicksort in C or http server in python.
* LLMs are still not too good at generating code, especially if the change is spread across many files in huge repo and is generally complicated enough. If LLM is good at writing some code, maybe that code should not be written at all.
* At the same time, LLMs are pretty good at trying to explain what the code is trying to accomplish (search space is different)
* Pretty good at suggesting alternatives/cleaner ways/already existing tools to achieve something.
* Pretty good at helping with corner cases/review.

The expectations here are:
* It won't write code for me;
* It will help me read/understand code faster;
* It will help me write a little bit better code.

Multi-backend support was implemented to be able to experiment on different local/closed models, for example:
1. To get initial assesment of a complicated problem you might ask sonnet 3.5. 
2. Claude will charge per token in the input and each message will send/process all the tokens again, so if you keep chatting you get O(n^2). While it's pretty cheap - 1000 tokens of output is ~1.5 cents, it can still add up. We can also expect ~5x for next opus model.
3. The idea is that we might be able to, for example, ask Sonnet 3.5 original question, ask for some options/alternatives and then continue the conversation with a different bot (maybe haiku, maybe local llama, etc.).

Key features:
* use both Sonnet/local llama.cpp within same chat session. Can have multiple bots to pick on based on problem complexity/cost/capabilities/etc.
* streaming response from llama.cpp server and show in vim right away. This is important for large models running locally - llama3 70B gets ~8 tps on m2 ultra, which is very close to typical human reading time, so we can just read as the reply is getting produced.
* easily share context based on visual selection in vim. Be able to select lines, hit a hotkey and ask 'what is it doing?', 'what might be corner cases here?', 'how would you modernize this code?', 'how would you test this code?'.
* kv cache warmup to save on local prompt processing time. We can warmup KV cache for the lengthy multiple-turn chat session or a large code selection before we finished typing the question, thus amortizing the prompt processing cost. Hit hotkey, selection/previous messages are already being worked on in parallel while you are typing the question.

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
