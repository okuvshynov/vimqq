#!/bin/bash
set -e  # Exit on any error

cd /app/vimqq/

# Running vimqq 
vim -u /app/vimrc -c "QQI @$VQQ_ENG_BOT add sys_msg warning logging to deepseek_api in case of Unexpected Reply"

# TODO: add verification

# run existing unit tests
themis tests/local
