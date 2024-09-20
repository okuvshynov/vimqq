#!/usr/bin/env bash

setup_vimqq_env() {
    local vimqq_path=$1
    local test_dir

    if [ -z "$vimqq_path" ]; then
        echo "Usage: setup_test_environment <vimqq path>"
        return 1
    fi

    # Expand the relative path to an absolute path
    vimqq_path=$(realpath "$vimqq_path")

    # Create a temporary directory for the test
    test_dir=$(mktemp -d)
    cd "$test_dir"
    mkdir -p rtp/pack/plugins/start/
    cp -r "$vimqq_path" rtp/pack/plugins/start/

    cat > vimrc <<EOF
set nocompatible
let g:vqq_log_file = "$test_dir/log.txt"
let g:vqq_chats_file = "$test_dir/db.json"
let g:vqq_llama_servers = [{'bot_name': 'mock', 'addr': 'http://localhost:8889'}]
set packpath=$test_dir/rtp
:packloadall
EOF

    echo "$test_dir"
}

cleanup() {
    local test_dir=$1
    rm -rf "$test_dir"
}

run_vim_test() {
    local test_dir=$1
    local test_script=$2

    # Create test script
    echo "$test_script" > "$test_dir/test_script.vim"

    # Run Vim with the test configuration and script
    vim -N -u "$test_dir/vimrc" -S "$test_dir/test_script.vim" --not-a-term
}
