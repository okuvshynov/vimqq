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
echo "Using port $port"

working_dir=$(setup_vimqq_env "$vimqq_path" "$port")
cd $working_dir
echo "Using temp directory: $working_dir"
trap 'cleanup "$working_dir"' EXIT

serv_pid=$(setup_mock_serv "$working_dir" "$port")

test_script="$(cat "$script_dir/data/$testname.vim")"
expected="$script_dir/data/$testname.out"

run_vim_test "$working_dir" "$test_script"

stop_mock_serv "$serv_pid"

outfile="$working_dir/$testname.out"

# TODO: better handling of time
sed 's/[0-9][0-9]:[0-9][0-9]/00:00/' "$outfile" > "$outfile.observed"

if diff -q "$expected" "$outfile.observed"; then
    echo "Test passed"
    exit 0
else
    echo "Test failed"
    exit 1
fi
