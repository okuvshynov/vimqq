Use vim-themis for testing.

To run all local tests:
```
themis tests/local
```
These tests do not depend on remote API calls. Requires python + flask for mock server.

To run individual test files:
```
themis path/to/test_file.vim
```
For example:
```
themis tests/local/test_str.vim    # run string manipulation tests
themis tests/local/test_fmt.vim    # run formatting tests
```
All test files follow the pattern test_*.vim and can be run individually.
