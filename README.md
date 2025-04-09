# Vim quick question (vim-qq)

**Undergoing major experimental changes for now**

AI plugin for Vim/NeoVim with focus on local evaluation, flexible context and aggressive cache warmup to hide latency.

https://github.com/user-attachments/assets/f1b34385-c6e2-4202-a17d-2ef09e83becc

Features (including experimental)
* Support for both remote models through paid APIs (Claude, Gemini) and local models via llama.cpp server;
* automated KV cache warmup for local model evaluation;
* dynamic warmup on typing - in case of long questions, it is a good idea to prefill cache for the question itself;
* human-readable hierarchical project indexing;
* llm agents in different roles: engineer, reviewer, etc.
* fully closing the loop and implementing complex features E2E
