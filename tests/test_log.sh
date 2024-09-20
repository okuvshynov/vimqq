#!/usr/bin/env bash

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$tests_dir"/libtest.sh

vimqq_path=$1
if [ -z "$vimqq_path" ]; then
    echo "Usage: $0 <vimqq path>"
    exit 1
fi

test_dir=$(setup_vimqq_env "$vimqq_path")
trap 'cleanup "$test_dir"' EXIT

test_script=':call vimqq#log#info("hello world")
:qa!'

run_vim_test "$test_dir" "$test_script"

# check that log.txt has a single line ending with "hello world"
log_file="$test_dir/log.txt"
if [ -f "$log_file" ] && [ "$(wc -l < "$log_file")" -eq 1 ] && [ "$(tail -c 12 "$log_file")" = "hello world" ]; then
    echo "Test passed"
    exit 0
else
    echo "Test failed"
    exit 1
fi
