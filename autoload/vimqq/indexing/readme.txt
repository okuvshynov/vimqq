Even for medium-size projects full index is too large and embedding lookup is too unreliable.
For linux kernel, total length of all filenames is 741285 characters. There's no way to give this as an input to a model, let alone the summaries for each file.

What can we do:
* hierarchical index, with ability to explore the directories
* graph-based index with 'connections' inferred from commit history
* some combination of files now + commits themselves.
* something with source code itself (e.g. treesitter)
* something from runtime info?
