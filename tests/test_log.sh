#!/bin/bash

# vimqq version/implementation to test
vimqq_path=$1
if [ -z "$vimqq_path" ]; then
  echo "Usage: $0 <vimqq path>"
  exit 1
fi
# Expand the relative path to an absolute path
vimqq_path=$(realpath "$vimqq_path")

# TODO: check vim version >= 8.??

# Create a temporary directory for the test
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR" || exit 1

# set up cleanup for the working directory
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# copy vimqq to vim new runtimepath
mkdir -p rtp/pack/plugins/start/
cp -r "$vimqq_path" rtp/pack/plugins/start/

# minimal config to load only our plugin
cat > minimal_vimrc <<EOF
set nocompatible
set packpath=$TEST_DIR/rtp
:packloadall
let g:vqq_log_file = "$TEST_DIR/log.txt"
let g:vqq_chats_file = "$TEST_DIR/db.json"
EOF

# Test script: log hello world
cat > test_script.vim <<EOF
:call vimqq#log#info("hello world")
:qa!
EOF

# start vim with modified runtime path and config
# and run test script
vim -N -u minimal_vimrc -S test_script.vim --not-a-term > /dev/null 2> /dev/null

# check that log.txt has a single line ending with "hello world"
if [ -f log.txt ] && [ "$(wc -l < log.txt)" -eq 1 ] && [ "$(tail -c 12 log.txt)" = "hello world" ]; then
    if [ -n "$DEBUG_VIMQQ_TEST" ]; then
        echo "Test passed"
    fi
    exit 0
else
    if [ -n "$DEBUG_VIMQQ_TEST" ]; then
        echo "Test failed"
    fi
    exit 1
fi
