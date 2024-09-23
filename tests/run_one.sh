#!/usr/bin/env bash

# generic test runner. takes 2 arguments:
#   - vimqq_path - path to the tested plugin
#   - testname - name of test used to construct in/out files
#
#  test prepares mock server, and runs "$testname.vim" script.
#  script is expected to produce $testname.out in the working dir
#  and we'll compare it with $testname.expected

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$script_dir"/libtest.sh

testname=$1
vimqq_path=$2
if [ -z "$vimqq_path" ]; then
    # assume we are running test script from the same version of the code
    vimqq_path="$script_dir"/..
fi

# Expand the relative path to an absolute path
vimqq_path=$(realpath "$vimqq_path")

port=$(pick_http_port)
echo "Using port $port for mock llama server"

working_dir=$(setup_vimqq_env "$vimqq_path" "$port")
cd $working_dir
echo "Using temp directory: $working_dir"
if [ -z "$VIMQQ_KEEP_DIR" ]; then
    trap 'cleanup "$working_dir"' EXIT
fi

serv_pid=$(setup_mock_serv "$working_dir" "$port")

test_script="$script_dir/data/$testname.vim"
expected="$script_dir/data/$testname.out"
expected_server_stats="$script_dir/data/$testname.json"

set -x
run_vim_test "$working_dir" "$test_script"
vim_code=$?

echo "vim returned $vim_code"
set +x

if [ -f "$expected_server_stats" ]; then
    server_stats=$(curl -s http://localhost:$port/stats)    
    echo $server_stats
    diff <(jq -S . < "$expected_server_stats") <(echo "$server_stats" | jq -S .)
    server_match=$?
fi

echo "Stopping server"

stop_mock_serv "$serv_pid"

echo "Server match: $server_match"

if [ $vim_code -eq 0 ] && ([ -z "$server_match" ] || [ $server_match -eq 0 ]); then
    echo "Test passed"
    exit 0
else
    echo "Test failed"
    exit 1
fi
