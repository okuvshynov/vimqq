#!/usr/bin/env bash

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$tests_dir"/libtest.sh

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
#trap 'cleanup "$test_dir"' EXIT

test_script='function! WriteAndQuit(t)
execute "write history.txt"
execute "qa!"
endfunction
:Q @mock hello
call timer_start(5000, "WriteAndQuit")'

serv_pid=$(setup_mock_serv "$test_dir" "$port")

run_vim_test "$test_dir" "$test_script"

stop_mock_serv "$serv_pid"

history_file="$test_dir/history.txt"

if [ -f "$history_file" ] && [ "$(wc -l < "$history_file")" -eq 2 ] && [ "$(tail -c 6 "$history_file")" = "01234" ]; then
    echo "Test passed"
    exit 0
else
    echo "Test failed"
    exit 1
fi

