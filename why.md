## Requirements:

- work with vim
- work with local model. fast enough.
    - streaming
    - warmup
    - aggressive cache reuse/chat reuse
- work with remote as well. Switching between models
- writing code vs explanation/tutoting/brainstorming/refactoring/etc.
- flexible way to include context.

Ideal scenario (we are not quite there yet) that it would work similar to gutentags - you install it once and forget about it.

### Demo

#### Importance of warmup.

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

As we can see, there's almost no wait time for warmup option.

### Examples I was interested in

Not much about code completion.

The context here is file (some c++ class) + ctags exploration
```
:Q -ft @llama I've built this 10 years ago, give a list of simple and easy to review changes to modernize this code. Check if new features in language and std library can be used to simplify/imrpove it.
```

The context here is visual selection
```
:'<,'>QQ -ns @llama How would you refactor these three methods? Give step by step directions.
```

The context is entire small project here, ~20k tokens.
```
:Q -p @llama can you help brainstorm a roadmap for this project?
```

Now after some discussion about roadmap I might want to get to specifics. I should be able to fork the chat while reusing some of the cached context - so that model won't have to evaluate 20k tokens again:

```
:QF Let's work on the foo() and bar() improvements. Provide instructions to junior software engineer. 
```

This would reuse the cached data for the project itself and start producing tokens ~immediately.

### Cost of remote API.

Claude API is stateless. Internally they might (and should) make some caching/best effort stickiness, but from the outside each API call is charged as if it is evaluated from scratch. This means, for a long conversation you get O(N^2) cost. For example, if you started with a large context for your project (say, 20k tokens) and had a discussion for 20 rounds, you'll get charged for 400k tokens input. It is still pretty cheap for current sonnet 3.5 model, ~$1.2, but:
- we ignored all the output and next inputs in the discussion. 
- it can still add up over time
- project might be larger, and you still might want to include all of it
- it might have a psychological effect of 'is it worth to ask this question'? It's better to not have to think about it at all
- we can reasonably expect opus 3.5 to be significantly better and 5x more expensive compared to sonnet 3.5

### Running good local models

All the numbers below are for running llama70b 3.1 instruct, quantized to 8 bit on M2 Ultra.

1. Stream output. The output here is primary for human consumption, no tool interactions yet. Therefore, if we keep up with human reading speed, it is good enough, we don't need 1000 t/s. For the configuration above I was getting ~8-9 t/s which seems reasonable.
2. Warmup queries. Processing the prompt with large context becomes slow. To overcome that, we can send a warmup query with the context before user started typing the question. For example, 
    - select a function or entire file
    - press hotkey which would format the selection and send it to the server together with previous messages in the chat session;
    - prompt opens in command-line 
    - user starts typing the question
    - when user finished typing, we send a 'real' query, and server might have already processed a significant portion of the context. 
    This way we can amortize context processing cost and reduce time to first token significantly
3. chat forking. This is a further exploration of the (2)

Serverside improvements (e.g. speculative decoding) are orthogonal to this. 

### Project size

1. For tiny educational examples we can just include entire thing
2. For small-to-medium projects which fit into context but are slow to process we might either still include them but use caching/warmup/forking aggressively or use selective context (e.g. just some files based on ctags)?
3. For large projects there likely needs to be embedding store updated in realtime + code graph build with static analysis tool.
