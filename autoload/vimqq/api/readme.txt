This is OpenAI-like API implemented in vimscript

While different providers use similar API, they differ in some details and it makes sense to implement a single API
layer which would be used by higher-level abstractions.

Example differences:
 - llama.cpp API calls max_tokens n_predict
 - anthropic has a separate field for system prompt
 - there are more differences in tool calling APIs, which we'll also include here
 - deepseek has 'content' and 'reasoning_content' as part of the output
 - anthropic has different tool calling convensions, especially with streaming

API consists of a single call chat(params), which is similar to chat.completions.create.

params can contain:

 - model: str -- model name
 - messages: list -- messages (including system prompt) in format {'role' : 'user', 'content' : 'abc'}. 
 - max_tokens: int -- how many tokens to generate
 - stream: bool - stream response
 - on_complete: func(params) -- callback to call on chat completion
 - on_chunk: func(params, chunk) -- callback to call on new chunk of text. For non streaming requests, will be called once.

