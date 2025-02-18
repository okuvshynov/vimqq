FROM ubuntu:22.04

# Install required packages
RUN apt-get update && apt-get install -y \
    vim \
    git \
    curl \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# vimqq version to be benchmarked
RUN mkdir -p ~/.vim/pack/plugins/start/vimqq
RUN git clone https://github.com/okuvshynov/vimqq.git ~/.vim/pack/plugins/start/vimqq
RUN cd ~/.vim/pack/plugins/start/vimqq && git checkout 9598c55de2c8954beb4af5b01c8632b3ff051e50
# vimrc file with bot definition
COPY vimrc /app/vimrc

# Target project - something vimqq is going to work on. In this case, it is vimqq itself.
RUN cd /app
RUN git clone https://github.com/okuvshynov/vimqq.git 
RUN cd vimqq && git checkout 8aaa0bfd0b161640657559a4bac795a8a7761d30

# vimqq test dependencies. Different project might need different setup.
RUN pip3 install flask
RUN mkdir -p ~/.vim/pack/plugins/start/vim-themis
RUN git clone --depth 1 https://github.com/thinca/vim-themis.git ~/.vim/pack/plugins/start/vim-themis/
ENV PATH="~/.vim/pack/plugins/start/vim-themis/bin:${PATH}"

# Copy build script into container
COPY bm_run.sh /app/bm_run.sh
RUN chmod +x /app/bm_run.sh

# Script will be executed when container runs
ENTRYPOINT ["/app/bm_run.sh"]

