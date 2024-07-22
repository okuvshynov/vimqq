#!/bin/bash

source_dir=.
dest_dir=~/.vim/pack/plugins/start/vimqq/

# Create the destination directory if it doesn't exist
mkdir -p "$dest_dir"

# Find all .txt files and copy them with their directory structure
find "$source_dir" -type f -name "*.vim" -exec bash -c '
    file="$1"
    src_dir="$2"
    dst_dir="$3"
    rel_path="${file#$src_dir/}"
    mkdir -p "$dst_dir/$(dirname "$rel_path")"
    cp "$file" "$dst_dir/$rel_path"
' bash {} "$source_dir" "$dest_dir" \;
