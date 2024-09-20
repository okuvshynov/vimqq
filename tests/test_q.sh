#!/usr/bin/env bash

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$tests_dir"/libtest.sh

vimqq_path=$1
if [ -z "$vimqq_path" ]; then
    echo "Usage: $0 <vimqq path>"
    exit 1
fi

test_dir=$(setup_vimqq_env "$vimqq_path")
cd $test_dir
echo $test_dir
trap 'cleanup "$test_dir"' EXIT

test_script='function! WriteAndQuit(t)
execute "write history.txt"
execute "qa!"
endfunction
:Q @mock hello
call timer_start(5000, "WriteAndQuit")'

python $vimqq_path/tests/mock_llama.py --port 8889 > /dev/null 2> /dev/null &
SERVER_PID=$!

sleep 1

run_vim_test "$test_dir" "$test_script"

history_file="$test_dir/history.txt"

if [ -f "$history_file" ] && [ "$(wc -l < "$history_file")" -eq 2 ] && [ "$(tail -c 6 "$history_file")" = "01234" ]; then
    echo "Test passed"
    exit 0
else
    echo "Test failed"
    exit 1
fi

if ps -p $SERVER_PID > /dev/null
then
    kill $SERVER_PID
fi

