#!/bin/bash
set -e  # Exit on any error

cd /app/vimqq/

# Running vimqq 
vim -u /app/vimrc -c 'QQI @sonnet after several refactor changes, main.vim and cmd.vim can be merged. Do the merge and make corresponding changes in vimqq.vim file as well'

# imprerfect verification

# verify that at least one file was deleted
if ! git status --porcelain | grep -q "^ D"; then
    echo "No deleted file found"
    exit 1
fi

# run existing unit tests
themis tests/local
