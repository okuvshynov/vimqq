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

Suite name should match file name for easier lookup.

As API is reimplemented in vimscript over raw HTTP, it's important to test this part too. To do that, there are mock servers we can use. 

We need, however, some way to test mock server itself. To do that there's a separate testing suite which is based on 'official' Python client - we check that official anthropic package can work with our mock server.

To run these tests:
```
pytest tests/mocks
```


