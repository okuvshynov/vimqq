# VimQQ Documentation

## Overview

VimQQ (Vim Quick Question) is an AI-powered plugin for Vim and NeoVim that provides interactive communication with large language models directly from your editor. It focuses on minimizing latency through local model evaluation, aggressive caching techniques, and context-aware prompting.

The plugin supports both remote AI models through paid APIs (Claude, Deepseek) and local models via llama.cpp server, giving users flexibility in choosing their preferred AI backend while maintaining a consistent interface.

## Key Features

### AI Model Integration

- **Multiple Model Support**: Use cloud-based models like Claude and Deepseek or local models through llama.cpp
- **Bot System**: Create and configure multiple AI agents for different purposes (chat, code review, indexing)
- **Bot Selection**: Select bots using @botname syntax or configure default bots

### Latency Optimization

- **KV Cache Warmup**: Automatically prepares model cache when:
  - Opening a chat to reduce initial response time
  - During typing to pre-fill context for long questions
- **Stream Responses**: Receive AI responses in real-time as they're generated

### Context Management

- **Hierarchical Project Indexing**: Builds an index of your codebase to provide relevant context to AI queries
- **Git Integration**: Uses Git history to understand relationships between files
- **Related Files Analysis**: Creates a graph representation of file relationships for better context

### Tool Execution

- **File Operations**: Get file content, edit files, and create new files directly from AI conversations
- **Shell Commands**: Execute shell commands and return results to the AI
- **Asynchronous Execution**: Tools operate asynchronously and chain together for complex operations

### User Interface

- **Chat History**: Maintain and browse through conversation history
- **FZF Integration**: Fuzzy find through chats for quick access
- **Status Updates**: Visual indicators for background tasks like indexing and warmup
- **Syntax Highlighting**: Different roles and message types have distinct highlighting

## Commands

| Command | Description |
|---------|-------------|
| `QQ <text>` | Send a question/message to the AI |
| `QQN <text>` | Start a new chat with the AI |
| `QQI <text>` | Send a question with indexed context |
| `QQT <text>` | Send a question with tools enabled |
| `QQList` | Show a list of all conversations |
| `QQFZF` | Use fuzzy finder to select a conversation |
| `QQLOG` | Open the log file in a split window |
| `QQG` | Build the project graph (for related files) |
| `QQGI` | Build the project index |
| `QQS` | Show current status of background tasks |

## Configuration

### Bot Configuration

Configure bots in your vimrc:

```vim
" Llama.cpp Servers
let g:vqq_llama_cpp_servers = [
    \ {'bot_name': 'llama', 'addr': 'http://127.0.0.1:8080', 'warmup_on_typing': v:true},
    \ {'bot_name': 'mistral', 'addr': 'http://127.0.0.1:8081'}
\ ]

" Claude API Models
let g:vqq_claude_models = [
    \ {'bot_name': 'claude', 'model': 'claude-3-5-sonnet-20241022'}
\ ]

" Set default bot
let g:vqq_default_bot = 'claude'
```

### Reviewer Bots

```vim
" Llama.cpp Reviewer Models
let g:vqq_llama_cpp_reviewer_models = [
    \ {'bot_name': 'llama_reviewer', 'addr': 'http://127.0.0.1:8080'}
\ ]

" Claude Reviewer Models
let g:vqq_claude_reviewer_models = [
    \ {'bot_name': 'claude_reviewer', 'model': 'claude-3-5-sonnet-20241022'}
\ ]
```

### Other Settings

```vim
" Path for storing chat history
let g:vqq_chats_dir = '~/.vim/vqq_chats'

" Log settings
let g:vqq_log_file = '~/.vim/vqq.log'
let g:vqq_log_level = 'INFO'  " Options: DEBUG, INFO, WARNING, ERROR, NONE
```

## Workflow Examples

### Basic Chat

1. Start a new conversation with `QQN What is the best way to optimize Vim startup time?`
2. Continue the conversation with `QQ Can you show me some examples?`
3. View conversation history with `QQList`

### Code Assistance with Context

1. Select a code snippet in visual mode
2. Run `QQI Explain this code and suggest improvements`
3. VimQQ will send the selected code plus contextual information from the project index

### Using Tools

1. Start a tool-enabled chat with `QQT Generate a Python script to process CSV files`
2. The AI might use tools to:
   - Create new files with `create_file`
   - Run shell commands to test the code with `run_cmd`
   - Get related files for context with `get_files`

### Code Review

1. Configure a reviewer bot in your vimrc
2. Select code in visual mode
3. Run `QQ @code_reviewer Review this code for bugs and performance issues`

## Project Architecture

VimQQ follows a modular architecture with these key components:

1. **Controller**: Central coordinator for the plugin (`vimqq/controller.vim`)
2. **API Layer**: Handles communication with AI providers (`vimqq/api/`)
3. **Bot System**: Manages different AI agents (`vimqq/bots/`)
4. **Indexing Engine**: Builds and maintains the project index (`vimqq/indexing/`)
5. **Tools Framework**: Enables AI to execute actions (`vimqq/tools/`)
6. **UI Components**: Manages the user interface (`vimqq/ui.vim`)
7. **Database**: Stores and retrieves chat history (`vimqq/db.vim`)

## Indexing Capabilities

The indexing system helps provide relevant context to AI queries by:

1. Creating a graph of related files based on Git history
2. Using a llama.cpp indexer to generate summaries of files
3. Storing these summaries in a searchable index
4. Providing relevant files as context when asking questions

To set up indexing:

1. Create a `.vqq` directory in your project root
2. Run `QQG` to build the graph of related files
3. Run `QQGI` to build the full index
4. Use `QQI` to include this context in your questions

## Advanced Features

### Warmup System

The warmup system reduces latency by:

1. Preloading the model's KV cache with chat history when opening a chat
2. Monitoring command-line input to warmup models during typing
3. Using the same prompt format for warmup as for actual queries

### Tool Pipeline

Tools can be chained together for complex operations:

1. AI suggests a series of tool calls
2. Each tool executes asynchronously
3. Results are passed back to the AI for analysis
4. The AI can make additional tool calls based on results

### Message Streaming

Responses are streamed in real-time:

1. First token latency is measured and tracked
2. Partial responses are displayed as they arrive
3. The UI updates incrementally as new content is received

## Troubleshooting

### Common Issues

1. **API Key Issues**: Ensure your API keys are properly set for remote models
2. **Local Model Connection**: Verify llama.cpp server is running and address is correct
3. **Indexing Failures**: Check .vqq directory exists and has write permissions
4. **High Latency**: Consider enabling warmup features or using a more powerful local model

### Logs

View detailed logs with `QQLOG` command or check the log file at the path specified by `g:vqq_log_file`.

### Debug Mode

Enable debug logging:

```vim
let g:vqq_log_level = 'DEBUG'
```

## Extending VimQQ

### Adding New Tools

Create a new tool by:

1. Adding a file to `autoload/vimqq/tools/`
2. Implementing the required interface (schema, run, run_async, format_call)
3. Adding the tool to the toolset in `toolset.vim`

### Supporting New AI Providers

Add support for new AI providers by:

1. Creating adapter and builder files in `autoload/vimqq/api/`
2. Implementing the API client in `autoload/vimqq/api/`
3. Creating a bot wrapper in `autoload/vimqq/bots/`
4. Adding the provider to the bot configuration system

## Version History

| Version | Date | Major Changes |
|---------|------|--------------|
| 0.0.6 | 2024-09-16 | Support for git blame context, Bug fixes |
| 0.0.7 | 2024-09-24 | Groq API support, Automated tests with mock servers, Bug fixes |
| 0.0.8 | 2024-12-19 | Autowarmup improvements, Bug fixes |
| 0.0.9 | 2025-02-07 | Experimental features |

## License

VimQQ is released under the MIT License. See LICENSE file for details.

Copyright © 2024 Oleksandr Kuvshynov