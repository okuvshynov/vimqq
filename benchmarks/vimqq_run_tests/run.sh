#!/bin/bash
set -e  # Exit on any error

# install flask for mock server
pip3 install flask

# install themis for vim testing
mkdir -p ~/.vim/pack/plugins/start/vim-themis
git clone https://github.com/thinca/vim-themis.git ~/.vim/pack/plugins/start/vim-themis/
export PATH="~/.vim/pack/plugins/start/vim-themis/bin:$PATH"

# clone vimqq
git clone https://github.com/okuvshynov/vimqq.git

# run tests
cd vimqq

python tests/mock_llama.py --port 8888 --logs /tmp/

#themis tests/local
