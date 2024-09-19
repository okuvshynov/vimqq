#!/usr/bin/env bash

# vimqq version/implementation to test
VIMQQ_PATH=$1
if [ -z "$VIMQQ_PATH" ]; then
  echo "Usage: $0 <vimqq path>"
  exit 1
fi

# Expand the relative path to an absolute path
VIMQQ_PATH=$(realpath "$VIMQQ_PATH")

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for script in "$CURRENT_DIR"/test_*.sh; do
  if [[ -e $script ]]; then
    TMP_FILE="$(mktemp)"
    "$script" "$VIMQQ_PATH" > "$TMP_FILE" 2>&1
    EXIT_CODE=$?
    SCRIPT_NAME=$(basename "$script")

    RESULT="\033[0;31m[ fail ]\033[0m"
    if [ $EXIT_CODE -eq 0 ]; then
      RESULT="\033[0;32m[ ok ]\033[0m"
    fi
    echo -e "$RESULT $SCRIPT_NAME"
    rm "$TMP_FILE"
  fi
done
