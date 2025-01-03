#!/usr/bin/env bash

# Find unused port to be used for mock http server communication
pick_http_port() {
    for port in $(seq 1024 65535); do
        (echo >/dev/tcp/127.0.0.1/$port) >/dev/null 2>&1 || { echo $port; return 0; }
    done
    echo "No unused ports found" >&2
    return 1
}

setup_vimqq_env() {
    local vimqq_path=$1
    local port=$2
    local test_dir

    # Expand the relative path to an absolute path
    vimqq_path=$(realpath "$vimqq_path")

    # Create a temporary directory for the test
    test_dir=$(mktemp -d)
    cd "$test_dir"
    mkdir -p rtp/pack/plugins/start/
    ln -s "$vimqq_path" rtp/pack/plugins/start/vimqq

    cat > vimrc <<EOF
set nocompatible
let g:vqq_log_file = "$test_dir/vimqq.log"
let g:vqq_log_level = 'DEBUG'
let g:vqq_chats_file = "$test_dir/vimqq_db.json"
let g:vqq_llama_servers = [{'bot_name': 'mock', 'addr': 'http://localhost:$port'}]
let g:vqq_time_format = "00:00"
let g:vqq_skip_init = 1
set packpath=$test_dir/rtp
EOF

    echo "$test_dir"
}

setup_mock_serv() {
    local test_dir=$1
    local port=$2
    local vimqq_path="$test_dir/rtp/pack/plugins/start/vimqq"

    python "$vimqq_path/tests/mock_llama.py" --port $port --logs $test_dir> "$test_dir/mock_server.stdout" 2> "$test_dir/mock_server.stderr" &
    server_pid=$!

    while ! curl --silent --fail http://localhost:$port/alive > /dev/null 2> /dev/null; do
      sleep 0.05
    done
    echo "$server_pid"
}

stop_mock_serv() {
    local server_pid=$1
    if ps -p $server_pid > /dev/null
    then
        kill $server_pid
    fi
}

cleanup() {
    local test_dir=$1
    rm -rf "$test_dir"
}

run_vim_test() {
    local test_dir=$1
    local test_script=$2
    if [ -z "$VIMQQ_VIM_BINARY" ]; then
        local vim_binary="vim"
    else
        local vim_binary="$VIMQQ_VIM_BINARY"
    fi

    # Run Vim with the test configuration and script
    if [[ $vim_binary =~ nvim$ ]]; then
      "$vim_binary" -N -u "$test_dir/vimrc" -S "$test_script"
    else
      "$vim_binary" -N -u "$test_dir/vimrc" -S "$test_script" --not-a-term
    fi
    local vim_code=$?
    return $vim_code
}
