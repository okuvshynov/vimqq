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

# Install dependencies:
RUN pip3 install flask

RUN mkdir -p ~/.vim/pack/plugins/start/vim-themis
RUN git clone --depth 1 https://github.com/thinca/vim-themis.git ~/.vim/pack/plugins/start/vim-themis/
ENV PATH="~/.vim/pack/plugins/start/vim-themis/bin:${PATH}"

# Copy build script into container
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

# Script will be executed when container runs
ENTRYPOINT ["/app/run.sh"]

