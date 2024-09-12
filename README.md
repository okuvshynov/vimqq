# Vim quick question (vim-qq)

AI plugin for Vim with focus on local model evaluation, code understanding and refinement, rather than providing autocomplete.

While there are many copilot-like plugins for different IDEs/editor (cody ai, tabby, etc.), I couldn't quite find what I needed. The requirements I had were:

- work with reasonably modern Vim, e.g. one preinstalled on MacOS;
- work with both Vim and NeoVim;
- work with local model evaluation. fast enough to be practical;
- work on Apple M1/M2 devices, which have limited compute power and would be slow to process long context;
- work with remote paid API as well;
- support switching models in the middle of discussion, e.g. from Claude Sonnet to local Llama 70 and back;
- focus on explanation/brainstorming/refactoring rather than autocomplete/generation - be able to run models which can explain some code to you;
- flexible way to include context;
- as few dependencies as possible;
- I expect myself to read and understand everything, so going much faster than my reading comprehension rate would be pointless. 10 t/s is good enough.

Ideal scenario (we are not quite there yet) that it would work similar to [gutentags](https://github.com/ludovicchabant/vim-gutentags) - you install it once and forget about it.

In order to make local model experience better, following features were implemented:
1. automatic cache warmup on context selection;
2. dynamic cache warmup during message input (while user types);
3. token streaming into Vim buffer, so we can see output right away;
4. chat forking, so we can reuse large initial context (e.g. entire project/subset of files) and start new conversation from that point.



https://github.com/user-attachments/assets/f1b34385-c6e2-4202-a17d-2ef09e83becc



### Example

#### Entire small project in context

Main use-case I was interested in is continuous work on small/medium project. I have multiple projects where entire code + documentation is fitting into the 128k context of modern models. I'd like to be able to keep chatting about it (including starting new chats) and asking for very specific improvements without having to process the entire project again and again.

Let's look at the example of [cubestat](https://github.com/okuvshynov/cubestat) - command-line monitoring tool.

First, we can send warmup query to get the context for the project processed:
```
:Q -wp @llama
```

`-wp` here means [w]armup entire [p]roject. Project boundary here is 'all source files in nearest parent directory of the currently open file with `.git/` in it'. 

Depending on local model used, hardware available and the size of the project this might take some time. On M2 Ultra and llama3.1 70B quantized to 8bit it takes a few minutes for cubestat. We process ~100 tokens/second and need to process 20000 tokens total.

We can put this command to `autocmd` to kick off when our project is opened or put it in vimrc.

Now we can give our assistant some task:
```
:Q -p @llama Let's work on refactoring metrics. We need to change base_metric to become a 'metric_group' and introduce new 'metric' class, which would represent a single data row. In new design, for example, gpu_metric would become a subclass of metric_group and each row within gpu_metric ('GPU {x} util %' or 'GPU {x} vram util') will become an instance of 'metric'.
```

If warmup has finished, we should start seeing the streamed output very soon, in a few seconds:

```
10:30 You: @llama Here's a code snippet:

+--2086 lines: ...---------------------------------------------------------

 Let's work on refactoring metrics. We need to change base_metric to become
 a 'metric_group' and introduce new 'metric' class, which would represent a
 single data row. In new design, for example, gpu_metric would become a sub
class of metric_group and each row within gpu_metric ('GPU {x} util %' or '
GPU {x} vram util') will become an instance of 'metric'.
10:30 llama: Here's a refactored version of the
...
```

Note that provided context is hidden in Vim fold, but it is still part of the message. If we would skip the warmup, we'll have to wait for the same 3 minutes to process the context.

After we got the code, we can ask follow-up questions:
```
:Q @llama How would you make the refactoring gradual, so that we can move each metric group to new abstraction one by one (say, GPU, then CPU, etc.) rather than having to migrate all at once.
```

Now imagine that we are done with metrics for now and need to take a look at other area, while keeping the entire project context. We can ask another question in the chat fork:
```
:QF how would you refactor label2 and label10 functions and extract shared functionality?
```
The fork currently keeps the context of the very first message but modifies the message itself and sends it in the new chat session. By doing that we can start chat from scratch, but keep context cache.

We can press 'q' in the chat window and navigate to chat list. We'll see two separate chats:

```
Jul 31 10:44 >Refactoring label2 and label10 Functions
Jul 31 10:37  Refactoring Metrics in Cubestat
```

After massive changes we can probably warmup again to refresh it, but it's not done automatically.

Let's do another fork:
```
:QF How would you make network_metric class to have shared scale? Now rx and tx have separate scales which might be confusing.
```

In this example llama gave good suggestion, but was slightly off, so I wanted to ask a follow-up question with some extra context selected.
To do that, I can navigate to that file, select lines I care about and send a message using [s]election as context. 
```
:'<,'>QQ -s @llama values in this case is a visible subset of the data points, not entire history of read values. We need to take this into account and probably modify how we query the metrics from the main rendering loop
```

Here our message will be appended to current chat. Note that if you do just that, you might notice a delay (the larger the selection, the longer the delay). This happens because we need to process the selection as well, not the question only. To amortize the cost and make it more user friendly, we can define a key mapping:

```
xnoremap <leader>w  :<C-u>'<,'>QQ -ws @llama<cr>:'<,'>QQ -s @llama
```

Now when we press `<leader>w` current [s]election will be sent to the server for warmup as well. It will be still part of current chat, so large original context will be kept. The command line will be prefilled with the prompt `:'<,'>QQ -s @llama ` and we'll be typing the question in parallel with selection processing.

#### ctags context

It is not always practical to add entire project to the context. While we can build embeddings and try to lookup relevant context that way, a much simpler option would be to use ctags and follow them from the selection. Here's a brief video illustration where we select relevant code and press the hotkey (see below). vimqq follows available ctags and gets some of the context from the destination and starts processing.

To demonstrate importance of context warmup we show two windows running the same query.

The left window the following shortcut was used:

```
" [w]armup llama with [s]election + c[t]ags
xnoremap <leader>wst :<C-u>'<,'>QQ -wst @llama<cr>:'<,'>QQ -st @llama
```

First, we send warmup query, then we prefill command line and wait for user input

The right window was using the following:
```
" [q]uery llama with [s]election + c[t]ags
xnoremap <leader>qst :<C-u>'<,'>QQ -st @llama
```

Just fill in the command line and wait for user input

https://github.com/user-attachments/assets/d0fd63c0-3ddf-41e4-a9d0-b1fa63ebd80d

In both situations we queried fresh server instance with no cache. As you can see, in warmup case we start seeing output right away, while for no-warmup case we have to wait for 5-10 seconds which is annoying and can result in losing focus.

### Cost of remote API.

Claude API is stateless. Internally they might (and should) make some caching/best effort stickiness, but from the outside each API call is getting charged as if it is evaluated from scratch. This means, for a long conversation you get O(N^2) cost. For example, if you started with a large context for your project (say, 20k tokens) and had a discussion for 20 rounds, you'll get charged for 400k tokens input. It is still pretty cheap for current sonnet 3.5 model, ~$1.2, but:
- we ignored all the output and next inputs in the discussion, which adds to the cost as well.
- it can still add up over time;
- project might be larger, and you still might want to include all of it
- it might have a psychological effect of 'is it worth to ask this question'? It's better to not have to think about it at all
- we can reasonably expect opus 3.5 to be significantly better and 5x more expensive compared to sonnet 3.5. Even if it would be so much better for higher-level discussion and planning, that we'd prefer to use it over local alternative, it would become very important to be able to swicth to cheaper/local model in the middle of discussion and avoid O(n^2) cost for expensive model
  
## requirements

* Vim 8.2+
* curl
* llama.cpp if planning to use local models
* Anthropic API subscription if planning to use claude family of models
* ctags if using extended context

## Full docs & installation

[VIM help file](doc/vimqq.txt)

## TODO

### Better context

Current options for context selection are:
1. No context, just the question
2. Visual selection in editor
3. Entire current file
4. Selection + files with ctags destinations from the selection
5. Entire project

There are more options we can add:
1. Embeddings
2. Language-specific static analysis tools (e.g. Jedi for python)
3. Tool-based exploration where model will tell us what to look up

### Other

- [ ] something about specifically reviewing code changes. constant review?
- [ ] openai API
- [ ] work with llamafile, so that we don't have to rely on separate install of llama.cpp
- [ ] title generation invalidates part of KV cache; need to change this and/or regenerate from scratch.
- [ ] rather than warmup on chat open, keep updating the local model as soon as new messages are sent
- [ ] fork with context - select something, hit the key and that would be extra context.
- [ ] double-check all buffer options (fixed width, etc)
- [ ] better prompt configuration
- [ ] update system prompt with some personal info/autocollecting that info

Later

- [ ] saving KV cache serverside
- [ ] test on Windows
- [ ] recording some feedback (e.g. good answer, wrong answer, etc).

### More examples

#### Modernizing old code 

Given a single old C++ source file come up with a list of possible improvements.
```
:Q -ft @llama Provide a list of simple and easy to review changes to modernize this code. Check if new features in language and std library can be used to simplify/imrpove it.
```

`-ft` - The context here is one source [f]ile + c[t]ags exploration.

#### Generic refactoring

Given a snippet from a single file suggest a way to refactor several methods in visual selection.
```
:'<,'>QQ -ns @llama How would you refactor these methods and extract common functionality? Give step by step directions.
```

`-ns` We start a [n]ew chat and use [s]election as context.

#### Brainstorming/planning

The context is entire small project, ~20k tokens.
```
:Q -p @llama can you help brainstorm a roadmap for this project?
```

Now after some discussion about roadmap I might want to get to specifics. I should be able to `fork` the chat while reusing large portion of the cached context - so that model won't have to evaluate 20k tokens again:

```
:QF Let's work on refactoring class Foo. Identify 5 tasks with detailed instructions for junior software engineer. 
```

This would reuse the cached data for the project itself and start producing tokens ~immediately.

#### Coaching/tutoring

Providing feedback on some experimental code.

```
:Q -fn @llama  Here's an implementation of Foo() done for educational purposes. Suggest some improvements and identify mistakes. Suggest further reading and relevant references.
```

`-fn` - The context here is current source [f]ile and we start a [n]ew chat.
