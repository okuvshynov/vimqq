Tests are organized into directores (suites).

unit/               -- unit tests
integration/auto/   -- automated integration tests, running with mock API server
integration/manual/ -- integrated tests running on real llama.cpp server and real API calls to Anthropic, DeepSeek, Groq, etc.

These tests are launching vim with minimal vimrc config and simulate queries to vimqq using mock server.

To run tests:

```
# all tests, default 'vim'
./tests/run.sh .

# unit tests, default 'vim'
./tests/run.sh unit

# auto integration tests, nvim
VIMQQ_VIM_BINARY=nvim ./tests/run.sh integration/auto
```

Requirements for tests:
1. python with flask
2. vim 8+ or nvim
3. jq for json comparison
4. works on linux/mac os

Configuration/env vars:
1. VIMQQ_VERBOSE - print out each test output
2. VIMQQ_KEEP_DIR - do not delete temp working directory
3. VIMQQ_VIM_BINARY - path/name for vim to use. default is 'vim'. Can be useful to test specific version or nvim.

