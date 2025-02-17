#!/bin/bash
set -e  # Exit on any error

# clone vimqq
git clone https://github.com/okuvshynov/vimqq.git

# run tests
cd vimqq
themis tests/local
