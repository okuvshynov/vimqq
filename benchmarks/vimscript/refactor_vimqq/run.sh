#!/bin/bash
set -e  # Exit on any error

cd /app/vimqq/

vim -u /app/vimrc -c 'QQI @sonnet after several refactor changes, main.vim and cmd.vim can be merged. Do the merge and make corresponding changes in vimqq.vim file as well'

git status
git diff
