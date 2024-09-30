#!/bin/bash

curl -s -X POST 'https://api.groq.com/openai/v1/chat/completions' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -d '@-'
