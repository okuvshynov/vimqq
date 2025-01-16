Use vim-themis for testing.

```
themis tests/local
```

Run local tests which do not depend on remote API calls. Requires python + flask for mock server.

```
themis tests/remote
```

Run remote tests which call remote APIs or local llama.cpp server.
Require API keys and cost balance to run.
