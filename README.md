# Vim quick question (vim-qq)

AI plugin for Vim/NeoVim with focus on local evaluation, flexible context
and aggressive cache warmup to hide latency.

Features:
 - flexible extra context - visual selection, ctags, current file, entire
   project, git blame history and combination of the above;
 - Support for both remote models through paid APIs (Groq, Claude) 
   and local models via llama.cpp server;
 - automated KV cache warmup for local model evaluation;
 - dynamic warmup on typing - in case of long questions, it is a good idea
   to prefill cache for the question itself.
 - mixing different models in the same chat sessions. It is possible to send 
   original message to one model and use a different model for the follow-up
   questions.
 - ability to fork the existing chat, start a new branch of the chat and 
   reuse server-side cache for the shared context.
 - Support both Vim and NeoVim;

What vimqq is not doing:
 - providing any form of autocomplete.  
 - generating code in place, typing it in editor directly, all communication
   is done in the chat buffer.

https://github.com/user-attachments/assets/f1b34385-c6e2-4202-a17d-2ef09e83becc

The motivation was mostly to 
 - experiment and improve on context usage, as this seems to be very underutilized area for coding assistant. Most I've seen in the past were ignoring the history stored in version control and looking at the code as a static snapshot, thus losing a lot of useful information
 - aggressively hide latency and precompute while typing for local setups, optimizing for performance rather than throughput

## Requirements
* Vim 8+ or NeoVim 
* curl
* git if using source control context
* most likely won't work on Windows as is, need to find where to test it;

## Quick start using Groq API

This might be the easiest option to try it out at the moment for free. 

Copy over the plugin itself:
```
    git clone https://github.com/okuvshynov/vimqq.git ~/.vim/pack/plugins/start/vimqq
```

Update helptags in vim:
```
    :helptags ~/.vim/pack/plugins/start/vimqq/doc
```

Register and get API key at https://console.groq.com/keys
Save that key to `$GROQ_API_KEY` environment variable. 
Add the configuration to your vimrc:

```
    let g:vqq_groq_models = [
	  \  {'bot_name': 'groq', 'model': 'llama-3.1-70b-versatile'}
    \]
```

vimqq will not work in compatible mode, so add this as well:
```
    set nocompatible
```

Now we can ask a question:
```
    :Q @groq What are basics of unix philosophy?
```

Let's look at another use-case, which demonstrates the importance
of correct context, not just embedding lookup. Consider this line of code
```
    bool check_tensors     = false; // validate tensor data
```
from llama.cpp, assuming we have a local clone of that repository.

https://github.com/ggerganov/llama.cpp/blob/441b72b9/common/common.h#L260

Let's select this line in visual mode and run the following command:

```
    :'<,'>QQ -nbs What checks are going to run when check_tensors is set to true?
```

The following should happen:
  - [n]ew chat will be started - we won't continue the Unix philosophy
    discussion;
  - vimqq will get the visual [s]election;
  - vimqq will run `git [b]lame` within the selected range and find commits
    changing it: https://github.com/ggerganov/llama.cpp/commit/017e6999
  - vimqq will format the message with system prompt, selected line, commit
    content and question itself;
  - after that we should see the pretty reasonable and informative reply, much
    better than in cases of embedding-based context lookup.

## Setting up local model


To use local models, get and build llama.cpp server

```
    git clone https://github.com/ggerganov/llama.cpp
    cd llama.cpp
    make -j 16
```

Download the model and start llama server:

```
    ./llama.cpp/llama-server
      --model path/to/model.gguf
      --chat-template llama3
      --host 0.0.0.0
      --port 8080
```

Add a bot endpoint configuration to vimrc file, for example
```
    let g:vqq_llama_servers = [
          \  {'bot_name': 'local', 'addr': 'http://localhost:8080'},
    \]
```

For local models, especially if running large models on slower machines - large RAM CPU-only, MacStudio, cache warmup becomes very important to hide latency.

It is convenient to define key bindings to combine warmup + main query:

```
    " [w]armup local with [s]election
    xnoremap <leader>w  :<C-u>'<,'>QQ -ws @local<cr>:'<,'>QQ -s @local<Space>
    " [w]armup local with [s]election and git [b]lame
    xnoremap <leader>wb  :<C-u>'<,'>QQ -wsb @local<cr>:'<,'>QQ -sb @local<Space>
```

Using the same example as in Groq case, we can select the line, press `<leader>wb`. System prompt + selection + relevant git commit will be sent to the local server to warmup the cache. 

Command line will get prefilled with the `:'<,'>QQ -sb @local ` so user can start typing question immediately. As user types, we might keep sending updates to the server so that it processes the part of question. This allows to hide the prompt processing latency and start getting streamed reply sooner.



https://github.com/user-attachments/assets/4edc6c1c-f334-4ebd-b130-742f5552215c



## Full docs

[VIM help file](doc/vimqq.txt)

