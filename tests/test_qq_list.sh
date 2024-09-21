#!/usr/bin/env bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$script_dir"/libtest.sh

vimqq_path=$1
if [ -z "$vimqq_path" ]; then
    echo "Usage: $0 <vimqq path>"
    exit 1
fi

port=$(pick_http_port)
echo "Using port $port"
test_dir=$(setup_vimqq_env "$vimqq_path" "$port")
cd $test_dir
echo "Using temp directory: $test_dir"
trap 'cleanup "$test_dir"' EXIT

serv_pid=$(setup_mock_serv "$test_dir" "$port")

test_script="$(cat "$script_dir/qq_list.vim")"
expected="$script_dir/qq_list.expected"

run_vim_test "$test_dir" "$test_script"

stop_mock_serv "$serv_pid"

list_file="$test_dir/list.txt"

# TODO: better handling of time
sed 's/[0-9][0-9]:[0-9][0-9]/00:00/' "$list_file" > "$list_file.observed"

if diff -q "$expected" "$list_file.observed"; then
    echo "Test passed"
    exit 0
else
    echo "Test failed"
    exit 1
fi
