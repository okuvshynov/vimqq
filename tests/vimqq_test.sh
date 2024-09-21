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

vimqq_path=$1
testname=$2
port=$(pick_http_port)
echo "Using port $port"
test_dir=$(setup_vimqq_env "$vimqq_path" "$port")
cd $test_dir
echo "Using temp directory: $test_dir"
trap 'cleanup "$test_dir"' EXIT

serv_pid=$(setup_mock_serv "$test_dir" "$port")

test_script="$(cat "$script_dir/$testname.vim")"
expected="$script_dir/$testname.expected"

run_vim_test "$test_dir" "$test_script"

stop_mock_serv "$serv_pid"

outfile="$test_dir/$testname.out"

# TODO: better handling of time
sed 's/[0-9][0-9]:[0-9][0-9]/00:00/' "$outfile" > "$outfile.observed"

if diff -q "$expected" "$outfile.observed"; then
    echo "Test passed"
    exit 0
else
    echo "Test failed"
    exit 1
fi
