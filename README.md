# vim quick question (vim-qq)

https://github.com/user-attachments/assets/d0c3a4d7-b1a0-4bc0-815b-a945f1ffe6a3

AI plugin with a focus on local model evaluation, code reading and refinement rather than writing code.

While impressive, LLMs are still not that good at writing original code. It is especially true for the scenarios where the change is spread out across multiple files in a huge repository, which is exactly what some very important and time consuming code changes are.

The commonly cited rule of thumb metric is that software engineers spend 10x more time reading and comprehending the code rather than writing new code and vimqq is an attempt to help with this aspect of the workflow.

Explaining code should be a much easier problem from both retrieval and generation points of view. When asked to write a new code in a complicated codebase, search space for both 'providing context' and 'getting next token' seems much larger than in cases of explaining a specific piece of code, where one can just follow all the references.

Features:
 - optional extra context via [ctags](https://github.com/universal-ctags/ctags). To answer questions about a piece of code one might need to navigate to other definitions which could be located in different files across the large codebase. Including entire codebase in the context quickly becomes impractical. Rather than doing embedding lookup we can utilize very commonly used ctags to add potentially relevant context to our queries; For example, in the video above ctags-based navigation was used to also pull `DisplayMode` definition to the context;
 - streaming response from llama.cpp server, so that user can start reading it as it is being generated. For example, Llama3-70B can produce 8-10 tokens per second on Apple M2 Ultra, which is very close to human reading rate. This way user will not waste much time waiting for reply;
 - KV cache warmup for llama.cpp. In cases of high-memory but low-compute hardware configuration for LLM inference (Apple devices, CPU-only machines) processing original prompt might take a while in cases of large context selection or long chat history. To help with that and further amortize the cost, it is possible to send and automate sending warmup queries to prefill the KV cache. In the video above llama.cpp server started working on processing the prompt + context at the same time as user was typing the question, and the reply started coming in immediately.
 - Both Claude/Anthropic remote models through paid API and local models via llama.cpp server (or compatible).
 - mixing different models in the same chat sessions. It is possible to send original message to one model and use a different model for the follow-up questions.

What vimqq is not doing:
 - generating code in place, typing it in editor directly, all communication is done in the chat buffer. It is reasonably easy to copy/paste the code.

## requirements

* vim 8.2+
* curl
* llama.cpp if planning to use local models
* Anthropic API subscription if planning to use claude family of models
* ctags if using extended context

## Full docs

[VIM help file](doc/vimqq.txt)

## TODO

- [ ] rather than warmup on chat open, keep updating the local model as soon as new messages are sent
- [ ] forking chats
- [x] better error handling in API calls and job start
- [ ] more custom examples like 'explain', 'cleanup', 'improve readability', 'give an example of using ...'
- [ ] double-check all buffer options (fixed width, etc)
- [ ] better prompt configuration

Later

- [ ] saving KV cache serverside
- [ ] working on Windows?
- [ ] incremental context retrieval/search with tool use. Which ctags to follow, which symbols to lookup, etc.
      something with language server? E.g. let LLM natigate with YCM-like commands? treesitter? etc.
- [ ] recording some feedback (e.g. good answer, wrong answer, etc).

completed:
- [x] simultaneous queries - lock the current chat
- [x] for small projects just upload entire codebase to the context
- [x] deleting chats
- [x] formatting for extended context to avoid wiping out cache
- [x] configirable extended context
- [x] ctags context generation
- [x] customize system prompt 
- [x] doc/help
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
