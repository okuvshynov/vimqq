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

echo ""
echo "== Setup =="
echo "Test case name: $testname"
echo "Environment options:"
echo "  VIMQQ_KEEP_DIR=$VIMQQ_KEEP_DIR"
echo "  VIMQQ_VERBOSE=$VIMQQ_VERBOSE"
echo "  VIMQQ_VIM_BINARY=$VIMQQ_VIM_BINARY"

port=$(pick_http_port)
echo "Mock llama server will use port $port"

working_dir=$(setup_vimqq_env "$vimqq_path" "$port")
cd $working_dir
echo "Working directory: $working_dir"

if [ -z "$VIMQQ_KEEP_DIR" ]; then
    echo "Working directory will be cleaned up automatically. To keep it after the test, set VIMQQ_KEEP_DIR environment variable."
    trap 'cleanup "$working_dir"' EXIT
fi

serv_pid=$(setup_mock_serv "$working_dir" "$port")
echo "Mock llama server started, pid=$serv_pid"

test_script="$script_dir/data/$testname.vim"
expected_server_stats="$script_dir/data/$testname.json"

echo ""
echo "== Running =="

if [ "$VIMQQ_VERBOSE" ]; then
    set -x
fi
run_vim_test "$working_dir" "$test_script"
vim_code=$?
if [ "$VIMQQ_VERBOSE" ]; then
    set +x
fi

if [ -f "$expected_server_stats" ]; then
    expected_stats=$(cat "$expected_server_stats")
    server_stats=$(curl -s http://localhost:$port/stats)    
    echo "  observed server stats: $server_stats"
    echo "  expected server stats: $expected_stats"
    diff <(jq -S . < "$expected_server_stats") <(echo "$server_stats" | jq -S .)
    server_match=$?
fi

echo "Stopping mock llama server"

stop_mock_serv "$serv_pid"

echo ""
echo "== Log files =="
echo "vimqq log:  $working_dir/vimqq.log"
echo "server log: $working_dir/mock_server.log"

echo ""
echo "== Results =="
echo "  vim returned code: $vim_code"
echo "  server stat match: $server_match"

if [ $vim_code -eq 0 ] && ([ -z "$server_match" ] || [ $server_match -eq 0 ]); then
    echo "  Result: OK"
    exit 0
else
    echo "  Result: FAIL"
    exit 1
fi
