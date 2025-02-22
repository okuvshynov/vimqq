To make our custom vimscript implementation of LLM APIs testable, let's create mock servers.

We need, however, to test the mock servers themselves, to make sure they respond what real one would respond.

To do that, we'll direct 'official' python clients to our mock server and test them. That'll give us more confidence in the correctness.

Let's start with anthropic.
mock_claude.py         -- mock implementation of anthropic API. We'll start with basic feature set, and cover more gradually.
test_mock_claude.py    -- unit test for mock_claude server, which uses anthropic package. Use pytest to start.
test_anthropic_api.vim -- test of our vimscript API implementation (anthropic_api.vim). Starts and uses mock_claude. Runs with themis.

Currently server supports streaming and tool calls. We also need:
1. Non streaming queries
2. Error scenarios
