These tests are launching vim with minimal vimrc config and simulate queries to vimqq using mock server.

To run tests:

```
# default 'vim'
./tests/run_all.sh

# use nvim or other specific binary/version
VIMQQ_VIM_BINARY=nvim ./tests/run_all.sh
```

Requirements for tests:
1. python with flask
2. vim 8+
3. jq for json comparison

Configuration/env vars:
1. VIMQQ_VERBOSE - print out each test output
2. VIMQQ_KEEP_DIR - do not delete temp working directory
3. VIMQQ_VIM_BINARY - path/name for vim to use. default is 'vim'. Can be useful to test specific version or nvim.

What tests should we write:
1. multi-bot
2. testing errors/timeouts
3. testing warmup on demand
4. testing auto warmup 
5. testing other context types - file, project, blame
6. testing navigation in chat list
7. testing forking

Improvements for tests themselves:
1. Run faster
2. detect if vim is present and avoid installing if yes
3. coverage?
4. test in vim himself. wait for N seconds for content to be equal to expectations.
