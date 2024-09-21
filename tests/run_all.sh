#!/usr/bin/env bash

# vimqq version/implementation to test
vimqq_path=$1
if [ -z "$vimqq_path" ]; then
  echo "Usage: $0 <vimqq path>"
  exit 1
fi

# Expand the relative path to an absolute path
vimqq_path=$(realpath "$vimqq_path")

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

n_failed=0
# iterate over all *.vim input scripts
for script in "$script_dir"/*.vim; do
    testname="$(basename "$script")"
    testname="${testname%.vim}"
    tmp_file="$(mktemp)"

    if [ -z "$VIMQQ_GITHUB" ]; then
        "$script_dir"/vimqq_test.sh "$vimqq_path" "$testname" > "$tmp_file" 2>&1
    else
        "$script_dir"/vimqq_test.sh "$vimqq_path" "$testname"
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
