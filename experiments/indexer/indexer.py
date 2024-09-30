# input is path to the folder
# first, let's just rebuild entire thing. Then let's figure out continuous.


# the input is:
# - content of one or more documents
# - current index/knowledge base (document -> summary)
# - goal is: write a summary for every current file/folder, can use get_file tool to get file content.
# - make sure to note some relationship (e.g. there could be source/header/test)

# documents - map {path -> content}
# index - current version of index. Index can look like:
# expanded_node 
#   - n_nodes -- how many nodes in total are inside
#   - list of all nodes (except children of non-expanded node)


# Different easy/hard scenarios:
#  - entire codebase fits into the context. 
#  - entire index will fit into the context. (example: vim, vscode)
#  - every file fits into the context. 

# Let's say our first use-case is:
# codebase might not fit
# each file easily fit and entire index easily fit

# 1. Produce empty index - all filenames and no sumaries
# 2. Pick several files (policy?). Use up to N tokens.
# 3. Send them with a query to summarize. Also include: entire (empty) index and a tool to 'get another file content'.
# 4. Add summaries to the index. Repeat.

# groq:
# "prompt_tokens":17268,"prompt_time":4.189816427 4k tokens/s
# say, 30M tokens -- 2 hours
# current rate limits - 20k/minute
