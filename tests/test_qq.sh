#!/bin/bash

# vimqq version/implementation to test
vimqq_path=$1
if [ -z "$vimqq_path" ]; then
  echo "Usage: $0 <vimqq path>"
  exit 1
fi
# Expand the relative path to an absolute path
vimqq_path=$(realpath "$vimqq_path")

# TODO: check vim version >= 8.??

# Create a temporary directory for the test
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR" || exit 1

if [ -n "$DEBUG_VIMQQ_TEST" ]; then
    echo "Working in temp dir: $TEST_DIR" 
fi

# set up cleanup for the working directory
cleanup() {
    rm -rf "$TEST_DIR"
}

if [ -n "$DEBUG_VIMQQ_TEST" ]; then
    trap cleanup EXIT
fi

# copy vimqq to vim new runtimepath
mkdir -p rtp/pack/plugins/start/
cp -r "$vimqq_path" rtp/pack/plugins/start/

# minimal config to load only our plugin
cat > minimal_vimrc <<EOF
set nocompatible
set packpath=$TEST_DIR/rtp
:packloadall
let g:vqq_log_file = "$TEST_DIR/log.txt"
let g:vqq_chats_file = "$TEST_DIR/db.json"
let g:vqq_llama_servers = [{'bot_name': 'mock', 'addr': 'http://localhost:8889'}]
EOF

cat > test_script.vim <<EOF
function! WriteAndQuit(t)
    execute 'write history.txt'
    execute 'qa!'
endfunction
:Q @mock hello
call timer_start(5000, 'WriteAndQuit')
EOF

if [ -n "$DEBUG_VIMQQ_TEST" ]; then
    echo "Setting up server"
fi

python $vimqq_path/tests/mock_llama.py --port 8889 > /dev/null 2> /dev/null &
SERVER_PID=$!

sleep 1

if [ -n "$DEBUG_VIMQQ_TEST" ]; then
    echo "Running vimscript"
fi

vim -N -u minimal_vimrc -S test_script.vim --not-a-term > /dev/null 2> /dev/null

if [ -f history.txt ] && [ "$(wc -l < history.txt)" -eq 2 ] && [ "$(tail -c 6 history.txt)" = "01234" ]; then
    if [ -n "$DEBUG_VIMQQ_TEST" ]; then
        echo "Test passed"
    fi
    exit 0
else
    if [ -n "$DEBUG_VIMQQ_TEST" ]; then
        echo "Test failed"
    fi
    exit 1
fi

if ps -p $SERVER_PID > /dev/null
then
    kill $SERVER_PID
fi

