#!/usr/bin/env bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# vimqq version/implementation to test
vimqq_path=$1
if [ -z "$vimqq_path" ]; then
    # assume we are running test script from the same version of the code
    vimqq_path="$script_dir"/..
fi

# Expand the relative path to an absolute path
vimqq_path=$(realpath "$vimqq_path")

n_failed=0
# iterate over all *.vim input scripts
for script in "$script_dir"/data/*.vim; do
    testname="$(basename "$script")"
    testname="${testname%.vim}"

    if [[ "$testname" =~ ^api_ ]]; then
        result="\033[0;33m[skip]\033[0m"
        echo -e "$result $testname"
        continue
    fi

    tmp_file="$(mktemp)"

    if [ -z "$VIMQQ_VERBOSE" ]; then
        "$script_dir"/run_one.sh "$testname" "$vimqq_path" > "$tmp_file" 2>&1
    else
        "$script_dir"/run_one.sh "$testname" "$vimqq_path"
    fi

    exit_code=$?

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
