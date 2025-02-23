#!/bin/bash
set -e  # Exit on any error

# clone vimqq
git clone https://github.com/okuvshynov/vimqq.git

cd vimqq

# install test requirements
pip3 install -r requirements.txt

# plugin tests
themis tests/local

# mock server tests
pytest tests/mocks
