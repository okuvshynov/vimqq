Each API produces a list of messages in slightly different format, which i need to transform to the internal format.

User and local logic works with internal format only, but can also produce 'messages'

When sending messages back, I need to transform them to format which the target API will understand.

My current thinking to design this was:

Each API implementation has 3 components:
1. main module handling actual interactions/network calls
2. message builder module - main module calls builder which creates a message in internal format
3. message adapter module, which transforms message from internal format to something API can understand.

The asymmetry here comes from the fact that builder needs to maintain internal state - APIs might return them in chunks, parts, etc. Adapter on the other hand has access to entire message, and can work on it in a stateless fashion.

There are also 'message builders' built for user input and internal app processing. This way the only way to create a new message is through one of the builder implementations.


This is OpenAI-like API implemented in vimscript

While different providers use similar API, they differ in some details and it makes sense to implement a single API layer which would be used by higher-level abstractions.

Example differences:
 - llama.cpp API calls max_tokens n_predict
 - anthropic has a separate field for system prompt
 - deepseek has 'content' and 'reasoning_content' as part of the output
 - anthropic has different tool calling convensions, especially with streaming
 - llama cpp server doesn't support streaming with tools
 - llama cpp server with jinja expects content to be string, not list of {type: 'text', 'text': 'hello world'}

API consists of a single call chat(params), which is similar to chat.completions.create.

params can contain:

 - model       : str -- model name
 - messages    : list -- messages (including system prompt) in format {'role' : 'user', 'content' : 'abc'}. 
 - max_tokens  : int -- how many tokens to generate
 - stream      : bool -- stream response
 - on_complete : func(params) -- callback to call on chat completion
 - on_chunk    : func(params, chunk) -- callback to call on new chunk of text. For non streaming requests, will be called once.

