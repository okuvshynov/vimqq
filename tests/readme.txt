These tests are launching vim with minimal vimrc config and simulate queries to vimqq.

Requirements for tests:
1. python with flask
2. vim 8+

Configuration/env vars:
1. VIMQQ_VERBOSE - print out each test output
2. VIMQQ_KEEP_DIR - do not delete temp working directory

What tests should we write:
1. multi-bot
2. testing errors/timeouts
3. esting warmup on demand
4. testing auto warmup 
5. testing other context types
6. testing navigation in chat list
7. testing forking

Improvements for tests themselves:
1. Run faster
2. detect if vim is present and avoid installing if yes
3. coverage?
4. test in vim himself. wait for N seconds for content to be equal to expectations.
