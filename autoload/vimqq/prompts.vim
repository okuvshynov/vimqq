if exists('g:autoloaded_vimqq_prompts_module')
    finish
endif

let g:autoloaded_vimqq_prompts_module = 1

let s:chain_prompt = 'You are an expert AI assistant that explains your reasoning step by step. For each step, provide a title that describes what you are doing in that step, along with the content. Decide if you need another step or if you are ready to give the final answer. Respond in JSON format with "title", "content", and "next_action" (either "continue" or "done") keys. USE AS MANY REASONING STEPS AS POSSIBLE. AT LEAST %d. BE AWARE OF YOUR LIMITATIONS AS AN LLM AND WHAT YOU CAN AND CANNOT DO. IN YOUR REASONING, INCLUDE EXPLORATION OF ALTERNATIVE ANSWERS. CONSIDER YOU MAY BE WRONG, AND IF YOU ARE WRONG IN YOUR REASONING, WHERE IT WOULD BE. FULLY TEST ALL OTHER POSSIBILITIES. YOU CAN BE WRONG. WHEN YOU SAY YOU ARE RE-EXAMINING, ACTUALLY RE-EXAMINE, AND USE ANOTHER APPROACH TO DO SO. DO NOT JUST SAY YOU ARE RE-EXAMINING. USE AT LEAST 3 METHODS TO DERIVE THE ANSWER. USE BEST PRACTICES. User will only see your final response. Steps are not going to be shown to the user. You can be use them to examine your own reasoning. Make sure that final answer is complete.
\
\Example of a valid JSON response:
\json
\{
\"title": "Identifying Key Information",
\"content": "To begin solving this problem, we need to carefully examine the given information and identify the crucial elements that will guide our solution process. This involves...",
\"next_action": "continue"
\}'

let s:repo_index_prompt = '
            \ You will be given entire content for a code repository. It will be formatted as a list of entries like this:
            \
            \<file>
            \<path>path/filename</path>
            \<content>
            \Content here....
            \</content>
            \</file>
            \
            \Your goal is to produce a detailed description of that repository. The description should be detailed enough for a junior engineer to understand where to look when working on a task. 
            \
            \List both high-level conceptual details and specific symbols/definitions and where they are defined/used. Make sure you do not omit any important details. After reading your description and task summary engineer should know where to look at and which files to check. Ensure that for each file you recorded entities/symbols defined and used.'

function! vimqq#prompts#chained(n_steps)
    return printf(s:chain_prompt, a:n_steps)
endfunction

function! vimqq#prompts#index()
    return s:repo_index_prompt
endfunction
