syntax clear

" Define the marker for the start of a message (adjust as needed)
syntax match chatMessageStart "^QQ_MSG_START" contained conceal
syntax match chatPromptEnd "QQ_PROMPT_END" contained conceal

syntax region chatPrompt start="^QQ_MSG_START" end="QQ_PROMPT_END" keepend contains=chatMessageStart,chatPromptEnd

highlight chatPrompt cterm=bold gui=bold

" Optionally, hide the marker
"highlight link chatMessageStart Conceal
"highlight link chatPromptEnd Conceal
