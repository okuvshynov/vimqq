Let's first do 'manual' benchmark - reimplement https://github.com/okuvshynov/vimqq/commit/2a70eff1b84973e3989a08a967c32090c0072989

We need to configure the following as input:

1. base commit (with index)
2. version of vimqq 'making change' (also some commit)
3. bot configuration (including passing API keys)
4. validation steps.

How do we generalize for different bots? 

We need to change:
1. Bot definition in vimrc
2. API key passed in env
3. The actual query string? No need, just use same name

docker build -t vimqq_vs_refactor0 . && docker run -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY -e VQQ_ENG_BOT=sonnet -it vimqq_vs_refactor0

docker build -t vimqq_vs_refactor0 . && docker run -e DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY -e VQQ_ENG_BOT=dschat -it vimqq_vs_refactor0
