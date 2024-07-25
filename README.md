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

```text
*vimqq.txt*  For Vim version 8.0  Last change: 2024 July 23

VIMQQ ~

Author: Oleksandr Kuvshynov

AI plugin with a focus on local model evaluation, code reading and refinement
rather than writing new code.

1. Introduction ................................................ |vimqq-intro|
2. Installation .............................................. |vimqq-install|
3. Usage ....................................................... |vimqq-usage|
4. Commands ................................................. |vimqq-commands|
5. Mappings ................................................. |vimqq-mappings|
6. Configuration .............................................. |vimqq-config|
7. Changelog ............................................... |vimqq-changelog|

==============================================================================
1. Introduction                                                    *vimqq-intro*

While impressive, LLMs are still not that good at writing original code. It
is especially true for the scenarios where the change is spread out across
multiple files in a huge repository, which is exactly what some very important
and time consuming code changes are.

The commonly cited rule of thumb metric is that software engineers spend 10x 
more time reading and comprehending the code rather than writing new code and
vimqq is an attempt to help with this aspect of the workflow.

What vimqq is not doing:
 - generating code in place, typing it in editor directly, all communication
   is done in the chat buffer. It is reasonably easy to copy/paste the code.

Features:
 - optional extra context via |ctags|. To answer questions about a piece of 
   code one might need to navigate to other definitions which could be 
   located in different files across the codebase. Including entire codebase 
   in the context quickly becomes impractical. Rather than doing embedding
   lookup we utilize very commonly used ctags to add potentially relevant
   context to our queries;
 - streaming response from llama.cpp server, so that user can start
   reading it as it is being generated. Llama3-70B can produce 8-10 tps 
   on Apple M2 Ultra, which is very close to human reading rate. 
   This way user will not waste any time waiting for reply;
 - KV cache warmup for llama.cpp. In cases of high-memory but low-compute
   hardware configuration for LLM inference (Apple devices, CPU-only machines)
   processing original prompt might take a while in cases of large context 
   or long chat history. To help with that and further amortize the cost,
   it is possible to send and automate sending warmup queries to prefill
   the KV cache. So the workflow could look like this:
    - User selects some code in vim visual mode;
    - User runs a command (potentially with configured hotkey). That command
      picks extra context, sends the incomplete message to the server and 
      moves focus to the command line, where user can enter the question;
    - server starts processing the query in parallel with user typing the 
      question, reducing overall wait time;
 - Support for both Claude remote models through paid API and local models 
   via llama.cpp server (or compatible);
 - mixing different models in the same chat sessions. It is possible to send 
   original message to one model and use a different model for the follow-up
   questions.

Explaining code should be a much easier problem from both retrieval and 
generation points of view. When asked to write a new code in a complicated
codebase, search space for both 'providing context' and 'getting next token'
seems much larger than in cases of explaining a specific piece of code, where
one can just follow all the references.

==============================================================================
2. Installation                                                  *vimqq-install*

vimqq uses |packages| for installation.

Copy over the plugin itself:
>
    git clone https://github.com/okuvshynov/vimqq.git ~/.vim/pack/plugins/start/vimqq

The command above makes vimqq automatically loaded at vim start

Update helptags in vim:
>
    :helptags ~/.vim/pack/plugins/start/vimqq/doc

vimqq will not work in 'compatible' mode. 'nocompatible' needs to be set.

To use local models, get and build llama.cpp server
>
    git clone https://github.com/ggerganov/llama.cpp
    cd llama.cpp
    make -j 16

Download/prepare the models and start llama server:
>
    ./llama.cpp/llama-server
      --model path/to/model.gguf
      --chat-template llama3
      --host 0.0.0.0
      --port 8080

Add a bot endpoint configuration to vimrc file, for example
>
    let g:vqq_llama_servers = [
          \  {'bot_name': 'llama', 'addr': 'http://localhost:8080'},
    \]

It is possible to have multiple bots with different names.

To use claude models, register and get API key. By default vimqq will look for 
API key in environment variable `$ANTHROPIC_API_KEY`. It is possible to 
override the default with 
>
    let g:vqq_claude_api_key = ...

Bot definition looks similar to local llama.cpp:
>
    let g:vqq_claude_models = [
          \  {'bot_name': 'sonnet', 'model': 'claude-3-5-sonnet-20240620'}
    \]

==============================================================================
3. Usage                                                           *vimqq-usage*  

Assuming we have a bot named "llama", we can start by asking a question:
>
    :VQQSend @llama What are basics of unix philosophy?

We can omit the tag as well, and the first configured bot will be used:
>
    :VQQSend What are basics of unix philosophy?

After running this command new window should open in vertical split showing
the message sent and response. If it is local llama bot, we should see
the reply being appended token by token.

Pressing "q" in the window would change the window view to the list of 
past messages. Up/Down or j/k can be used to navigate the list and <cr>
can be used to select individual chat.

The chat titles are generated by the same model as was used to produce
first reply in the chat thread, after the first response has arrived.

Let's add a mapping to demonstrate more complicated use-case.
>
    xnoremap <silent> <leader>WW :<C-u>call VQQWarmupNewEx('@llama')<cr>

Now, in visual mode user can select some lines of code, press <leader>WW and 
the following should happen:
  - vimqq will look at all ctags available within the selection and collect
    context from destinations;
  - it will send a warmup query with selected code, extra context pulled by
    ctags exploration to the server. Server will start processing this
    request and fill the KV cache;
  - it will also prefill the command line with ":'<,'>VQQSendNewCtxEx". User
    can start typing the specific question ('Why does it call foo() instead 
    of bar()').
  - sending a message will hit the same server which should be able to
    fill in the cache and process our request much faster.

==============================================================================
4. Commands                                                     *vimqq-commands*  

First group of commands can be used to send messages.

    - `:VQQSend [@bot] message` sends a message to current chat.
      It @bot tag is present, `@bot` will be used to generate response,
      otherwise `g:vqq_default_bot` is used. Only the message itself is sent.

    - `:VQQSendNew [@bot] message` sends a message to a new chat. 
      It @bot tag is present, `@bot` will be used to generate response,
      otherwise `g:vqq_default_bot` is used. Only the message itself is sent.

    - `:VQQSendCtx [@bot] message` sends a message to current chat.
      It @bot tag is present, `@bot` will be used to generate response,
      otherwise `g:vqq_default_bot` is used. Both message and the current 
      visual selection is sent.

    - `:VQQSendNewCtx [@bot] message` sends a message to a new chat. 
      It @bot tag is present, `@bot` will be used to generate response,
      otherwise `g:vqq_default_bot` is used. Both message and the current 
      visual selection is sent.

    - `:VQQSendCtxEx [@bot] message` sends a message to current chat.
      It @bot tag is present, `@bot` will be used to generate response,
      otherwise `g:vqq_default_bot` is used. Both message and the current 
      visual selection is sent. In addition to that, some context found
      by exploring ctags in the selection might be also included.

    - `:VQQSendNewCtxEx [@bot] message` sends a message to a new chat. 
      It @bot tag is present, `@bot` will be used to generate response,
      otherwise `g:vqq_default_bot` is used. Both message and the current 
      visual selection is sent. In addition to that, some context found
      by exploring ctags in the selection might be also included.

    the following prompt template is used for the messages with context:

>
    "Here's a code snippet:\n\n{vqq_ctx}\n\n{vqq_msg}"

    It can be modified by setting `g:vqq_context_template` variable.

Second group of commands is used for sending warmup queries.

    - `:VQQWarm [@bot]` will send current chat messages as a warmup query. 
      It @bot tag is present, `@bot` will be used to generate response,
      otherwise `g:vqq_default_bot` is used.

    - `:VQQWarmNew [@bot]` will send new chat as a warmup query. 
      It @bot tag is present, `@bot` will be used to generate response,
      otherwise `g:vqq_default_bot` is used. This warmup might be still
      useful in case of long system prompt.

    - `:VQQWarmCtx [@bot]` will send current chat messages as a warmup query. 
      Will also include the visual selection. It @bot tag is present, `@bot`
      will be used to generate response, otherwise `g:vqq_default_bot` is used.

    - `:VQQWarmNewCtx [@bot]` will send new chat as a warmup query. 
      Will also include the visual selection. It @bot tag is present, `@bot`
      will be used to generate response, otherwise `g:vqq_default_bot` is used.

    - `:VQQWarmCtxEx [@bot]` will send current chat messages as a warmup query. 
      Will also include the visual selection. It @bot tag is present, `@bot`
      will be used to generate response, otherwise `g:vqq_default_bot` is used.
      In addition to that, some context found by exploring ctags in
      the selection might be also included.

    - `:VQQWarmNewCtxEx [@bot]` will send new chat as a warmup query. 
      Will also include the visual selection. It @bot tag is present, `@bot`
      will be used to generate response, otherwise `g:vqq_default_bot` is used.
      In addition to that, some context found by exploring ctags in
      the selection might be also included.

Next group of commands is UI-related.

    - `:VQQList` will show the list of past chat threads. User can navigate the
      list and select chat session by pressing <CR>. This action will make chat
      session current.

    - `:VQQOpenChat chat_id` opens chat with id=`chat_id`. This action will make
      chat session current.

    - `:VQQToggle` shows/hides vimqq window.

A few notes about extra context selection. It depends on the existence of 
ctags for the codebase and will roughly follow default <CTRL+]> logic.
vimqq will pick several ctags and some area above/below potential location.
With empty ctags, extra context will be empty as well.

==============================================================================
5. Mappings                                                     *vimqq-mappings*  

vimqq adds no global key mappings, only the navigation within chat buffer.

In chat list view:
 - 'q'  will close the vim-qq window
 - <cr> will select chat session under cursor, open it and make current.

In chat view:
 - 'q' will open the chat list view while keeping the same current chat.

It is a good idea to define some for yourself, but before that we need to
look at several helper functions:

  - `VQQWarmup(bot)` will call `:VQQWarmCtx bot` and prefill command line with
    `:'<,'>VQQSendCtx bot`, so that user can start typing question immediately.

  - `VQQWarmupNew(bot)` will call `:VQQWarmNewCtx bot` and prefill command
    line with `:'<,'>VQQSendNewCtx bot`, so that user can start typing 
    question immediately.

  - `VQQWarmupEx(bot)` will call `:VQQWarmCtxEx bot` and prefill command line
    with `:'<,'>VQQSendCtxEx bot`, so that user can start typing question
    immediately.

  - `VQQWarmupNewEx(bot)` will call `:VQQWarmNewCtxEx bot` and prefill command
    line with `:'<,'>VQQSendNewCtxEx bot`, so that user can start typing 
    question immediately.

  - `VQQQuery(bot)` will prefill command line with `:'<,'>VQQSend bot`,
    so that user can start typing question immediately.

  - `VQQQueryNew(bot)` will prefill command line with `:'<,'>VQQSendNew bot`,
    so that user can start typing question immediately.

Using these functions we can define custom key mappings to improve productivity.

Let's assume we have configured two bots: `llama70` and `sonnet`:
>
    let g:vqq_llama_servers = [
          \  {'bot_name': 'llama70', 'addr': 'http://localhost:8080'}
    \]
    let g:vqq_claude_models = [
          \  {'bot_name': 'sonnet', 'model': 'claude-3-5-sonnet-20240620'}
    \]

Now we can define some key mappings
>
    " [w]armup llama70b
    xnoremap <silent> <leader>w :<C-u>call VQQWarmup('@llama70')<cr>
    " [w]armup new chat llama70b
    xnoremap <silent> <leader>ww :<C-u>call VQQWarmupNew('@llama70')<cr>
    " [W]armup llama70b with extra context
    xnoremap <silent> <leader>W :<C-u>call VQQWarmupEx('@llama70')<cr>
    " [W]armup new chat llama70b with extra context
    xnoremap <silent> <leader>WW :<C-u>call VQQWarmupNewEx('@llama70')<cr>
    " [q]uery llama70b
    nnoremap <silent> <leader>q :<C-u>call VQQQuery('@llama70')<cr>
    nnoremap <silent> <leader>qq :<C-u>call VQQQueryNew('@llama70')<cr>
    " query [s]onnet without selected context
    nnoremap <silent> <leader>s :<C-u>call VQQQuery('@sonnet')<cr>
    nnoremap <silent> <leader>ss :<C-u>call VQQQueryNew('@sonnet')<cr>
    " query [s]onnet with selected context in visual mode
    xnoremap <silent> <leader>s :<C-u>call VQQWarmup('@sonnet')<cr>
    xnoremap <silent> <leader>ss :<C-u>call VQQWarmupNew('@sonnet')<cr>

For example, <leader>ww in visual mode will get the selection, send warmup
query to llama70 bot, prefill command line with :'<,'>VQQSendNewCtx @llama70 
and wait for user input to complete the query.

For extra ctags-based context generation we can press <leader>WW and then
type in the question.

Note that because warmup is no-op for remote sonnet model, we can reuse
the same `VQQWarmup` functions to capture context and prepare the prompt.

All the commands above expect some user message. We can also prepare some key
mapping for predefined messages for commonly used patterns. For example:
>
    " [E]xplain
    xnoremap <silent> <leader>E :<C-u>execute "'<,'>VQQSendNewCtx @llama70 Explain how this code works."<cr>
    " [I]mprove
    xnoremap <silent> <leader>I :<C-u>execute "'<,'>VQQSendNewCtx @llama70 How would you improve this code?"<cr>

==============================================================================
6. Configuration                                                  *vimqq-config*  

Configuration is done using global variables with prefix `g:vqq`.

    - `g:vqq_llama_servers` - list of llama.cpp bots. Default is empty.
      Each bot configuration is a dictionary with the following attributes:
      - `bot_name`. string identification for this bot.
        Must be unique and consist of [a-zA-Z0-9_] symbols. Required
      - `addr`. Path to endpoint, in the http://host:port format. Required.
      - `healthcheck_ms`. How often to do healthcheck query.
        Optional, default is 10000ms (=10s)
      - `title_tokens`. When generating title for chat, up to this many
        tokens can be produced. Optional, default is 16.
      - `max_tokens`. When producing response, up to this many tokens can
        be produced. Optional, default is 1024.
      - `system_prompt`. System prompt to include in the query and steer 
        bot behavior. Optional, default is "You are a helpful assistant".

    - `g:vqq_claude_models` - list of claude bots. Default is empty.
      Each bot configuration is a dictionary with the following attributes:
      - `model`. Model to use, must be one the models supported by Claude.
        Check https://docs.anthropic.com/en/docs/about-claude/models for 
        the model list. Required.
      - `bot_name`. string identification for this bot.
        Must be unique and consist of [a-zA-Z0-9_] symbols. Required
      - `title_tokens`. When generating title for chat, up to this many
        tokens can be produced. Optional, default is 16.
      - `max_tokens`. When producing response, up to this many tokens can
        be produced. Optional, default is 1024.

    - `g:vqq_default_bot`. bot_name of the bot used by default, if user
      omits the tag. Optional, default is first bot.

    - `g:vqq_warmup_on_chat_open`. List of bot names for which to issue 
      a warmup query automatically, every time we opened chat history
      for some chat session. Useful for resuming old sessions. Default
      is empty list.

    - `g:vqq_context_template`. Template to use to construct the message
      if some code needs to be included as a context. Replaces placeholders
      {vvq_ctx} and {vvq_msg} with context (selected code) and message.
      Optional, default is "Here's a code snippet: \n\n{vqq_ctx}\n\n{vqq_msg}"

    - `g:vqq_width`. Default chat window width in characters.
      Optional, defutlt is 80.

    - `g:vqq_time_format`. Time format to use in chat sessions list.
      Optional, default is "%b %d %H:%M ", for example "July 23, 18:05"

    - `g:vqq_chats_file`. Path to json file to store message history.
        Optional, default is expand('~/.vim/vqq_chats.json')

==============================================================================
7. Changelog                                                   *vimqq-changelog*  
```

## TODO

- [ ] simultaneous queries - lock the current chat
- [ ] error handling in API calls and job start
- [ ] more custom examples like 'explain', 'cleanup', 'improve readability', 'give an example of using ...'
- [ ] double-check all buffer options (fixed width, etc)
- [ ] better prompt configuration
- [ ] saving KV cache serverside

Later

- [ ] working on Windows?
- [ ] incremental context retrieval/search with tool use. Which ctags to follow, which symbols to lookup, etc.
      something with language server? E.g. let LLM natigate with YCM-like commands? 
- [ ] recording some feedback (e.g. good answer, wrong answer, etc).

completed:
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
