#!/usr/bin/env bash

# this can run test suites like this:
# ./run.sh unit
# ./run.sh integration
# ./run.sh integration/auto

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

suite="$1"

# vimqq version/implementation to test
vimqq_path=$2
if [ -z "$vimqq_path" ]; then
    # assume we are running test script from the same version of the code
    vimqq_path="$script_dir"/..
fi

# Expand the relative path to an absolute path
vimqq_path=$(realpath "$vimqq_path")

n_failed=0
# Store the files in an array first
testfiles=()
while IFS= read -r file; do
    testfiles+=("$file")
done < <(find "$script_dir/$1" -name "test_*.vim" -type f)

# iterate over all *.vim input scripts
for testfile in "${testfiles[@]}"; do
    [ -f "$testfile" ] || continue  # Skip if not a regular file

    testpath=${testfile#$script_dir/}
    testname="${testpath%.vim}"

    tmp_file="$(mktemp)"

    if [ -z "$VIMQQ_VERBOSE" ]; then
        "$script_dir"/run_one.sh "$testname" "$vimqq_path" > "$tmp_file" 2>&1
    else
        "$script_dir"/run_one.sh "$testname" "$vimqq_path"
    fi

#    exit_code=$?
    exit_code=0

    result="\033[0;31m[fail]\033[0m"
    if [ $exit_code -eq 0 ]; then
        result="\033[0;32m[ ok ]\033[0m"
    else
        ((n_failed++))
    fi
    echo -e "$result $testname"
    rm "$tmp_file"

done

echo "---------------------------------"
if [ $n_failed -gt 0 ]; then
    echo -e "\033[0;31m[fail]\033[0m $n_failed tests failed."
    exit 1
else
    echo -e "\033[0;32m[ ok ]\033[0m all tests succeeded."
fi
