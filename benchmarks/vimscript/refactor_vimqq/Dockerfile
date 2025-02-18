FROM ubuntu:22.04

# Install required packages
RUN apt-get update && apt-get install -y \
    vim \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# vimqq version to be benchmarked
RUN mkdir -p ~/.vim/pack/plugins/start/vimqq
RUN git clone https://github.com/okuvshynov/vimqq.git ~/.vim/pack/plugins/start/vimqq
RUN cd ~/.vim/pack/plugins/start/vimqq && git checkout e33b3aa8afa9f594c72839d051a9587890342b27

# fetch another vimqq copy as a project to work on.
RUN cd /app
RUN git clone https://github.com/okuvshynov/vimqq.git 
RUN cd vimqq && git checkout 8aaa0bfd0b161640657559a4bac795a8a7761d30


# Copy build script into container
COPY run.sh /app/run.sh
COPY vimrc /app/vimrc
RUN chmod +x /app/run.sh

# Script will be executed when container runs
ENTRYPOINT ["/app/run.sh"]

