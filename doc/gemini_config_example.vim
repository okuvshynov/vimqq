" Example configuration for Gemini API in VimQQ

" Set your Gemini API key 
" Alternatively, you can set the GEMINI_API_KEY environment variable
let g:vqq_gemini_api_key = 'your_api_key_here'

" Define Gemini models to use
let g:vqq_gemini_models = [
    \ {
    \   'bot_name': 'geminipro',
    \   'model': 'gemini-pro',
    \   'system_prompt': 'You are a helpful AI assistant that provides concise and accurate information.',
    \   'max_tokens': 2000,
    \   'title_tokens': 64,
    \   'warmup': v:true,
    \ },
    \ {
    \   'bot_name': 'geminiultra',
    \   'model': 'gemini-ultra',
    \   'system_prompt': 'You are a helpful AI assistant with advanced reasoning capabilities.',
    \   'max_tokens': 4000,
    \   'title_tokens': 64,
    \   'warmup': v:true,
    \ }
\ ]

" Optionally set a Gemini model as the default bot
let g:vqq_default_bot = 'geminipro'