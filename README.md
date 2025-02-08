# Vim quick question (vim-qq)

AI plugin for Vim/NeoVim with focus on local evaluation, flexible context and aggressive cache warmup to hide latency.

**Undergoing major experimental changes for now**

* Support for both remote models through paid APIs (Claude, Deepseek) and local models via llama.cpp server;
* automated KV cache warmup for local model evaluation;
* dynamic warmup on typing - in case of long questions, it is a good idea to prefill cache for the question itself;
* human-readable hierarchical project indexing;
* llm agents in different roles: engineer, reviewer, etc.
* fully closing the loop and implementing complex features E2E

