# input is path to the folder
# first, let's just rebuild entire thing. Then let's figure out continuous.


# the input is:
# - content of one or more documents
# - current index/knowledge base (document -> summary)
# - goal is: write a summary for every current file/folder, can use get_file tool to get file content.
# - make sure to note some relationship (e.g. there could be source/header/test)

# documents - map {path -> content}
# index - current version of index. Index can look like:
# expanded_node 
#   - n_nodes -- how many nodes in total are inside
#   - list of all nodes (except children of non-expanded node)


# Different easy/hard scenarios:
#  - entire codebase fits into the context. 
#  - entire index will fit into the context. (example: vim, vscode)
#  - every file fits into the context. 

# Let's say our first use-case is:
# codebase might not fit
# each file easily fit and entire index easily fit


#### Rough process:

# 1. Produce empty index - all filenames and no sumaries
# 2. Pick several files (policy?). Use up to N tokens.
# 3. Send them with a query to summarize. Also include: entire (empty) index and a tool to 'get another file content'.
# 4. Add summaries to the index. Repeat with not-processed files and changed files. Include checksum in the index.

# groq:
# "prompt_tokens":17268,"prompt_time":4.189816427 4k tokens/s
# say, 30M tokens -- 2 hours
# "completion_tokens":693,"completion_time":2.7720000000000002
# current rate limits - 20k/minute


# sonnet 3.5?
# 

# on each iteration query would be:
# files to evaluate
# existing index

import os
import json
import hashlib
from typing import List, Dict, Any
from datetime import datetime

def should_process(file_path: str) -> bool:
    """
    Determine if a file should be processed based on its name, path, or content.
    Replace this implementation with your specific filtering logic.
    """
    # Example: Process only .txt and .pdf files
    return file_path.lower().endswith(('.txt', '.pdf'))

def get_file_info(path: str) -> Dict[str, Any]:
    """Get file information including relative path, size, and checksum."""
    ## TODO: compute token count instead
    size = os.path.getsize(path)
    with open(path, "rb") as file:
        file_hash = hashlib.md5()
        chunk = file.read(8192)
        while chunk:
            file_hash.update(chunk)
            chunk = file.read(8192)
    
    return {
        "path": path,
        "size": size,
        "checksum": file_hash.hexdigest()
    }

def process_directory(directory: str, root: str, previous_results: Dict[str, Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Process directory recursively and return file information for files that should be processed."""
    result = []
    for root_path, _, files in os.walk(directory):
        for file in files:
            full_path = os.path.join(root_path, file)
            relative_path = os.path.relpath(full_path, root)
            if should_process(relative_path):
                file_info = get_file_info(relative_path)
                if relative_path in previous_results and previous_results[relative_path]["checksum"] == file_info["checksum"]:
                    # Reuse previous result if checksum hasn't changed
                    result.append(previous_results[relative_path])
                else:
                    result.append(file_info)
    return result

def chunk_files(files: List[Dict[str, Any]], size_limit: int) -> List[List[Dict[str, Any]]]:
    """Split files into chunks respecting the size limit."""
    chunks = []
    current_chunk = []
    current_size = 0

    for file in files:
        if "processing_result" in file:
            # Skip files that have already been processed
            continue
        if current_size + file["size"] > size_limit:
            if current_chunk:
                chunks.append(current_chunk)
            current_chunk = [file]
            current_size = file["size"]
        else:
            current_chunk.append(file)
            current_size += file["size"]

    if current_chunk:
        chunks.append(current_chunk)

    return chunks

def process(files: List[Dict[str, Any]]) -> List[str]:
    """Mock function to simulate server processing."""
    return [f"Processed {file['path']}" for file in files]

def process_directory_with_limit(directory: str, size_limit: int, previous_results: Dict[str, Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Process directory with size limit and return results for files that should be processed."""
    files = process_directory(directory, directory, previous_results)
    chunks = chunk_files(files, size_limit)
    
    results = []
    for chunk in chunks:
        processing_results = process(chunk)
        timestamp = datetime.now().isoformat()
        for file, result in zip(chunk, processing_results):
            file_result = {
                "name": file["path"],
                "size": file["size"],
                "checksum": file["checksum"],
                "processing_result": result,
                "processing_timestamp": timestamp
            }
            results.append(file_result)
    
    # Add previously processed files that weren't reprocessed
    for file in files:
        if "processing_result" in file:
            results.append(file)
    
    return results

def load_previous_results(file_path: str) -> Dict[str, Dict[str, Any]]:
    """Load previous processing results from a JSON file."""
    if not os.path.exists(file_path):
        return {}
    with open(file_path, 'r') as f:
        previous_results = json.load(f)
    return {result["name"]: result for result in previous_results}

def main(directory: str, size_limit: int, output_file: str, previous_results_file: str):
    """Main function to process directory and save results."""
    previous_results = load_previous_results(previous_results_file)
    results = process_directory_with_limit(directory, size_limit, previous_results)
    
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)

if __name__ == "__main__":
    # Example usage
    directory = "D:/example_directory"
    size_limit = 1024 * 1024  # 1 MB
    output_file = "results.json"
    previous_results_file = "previous_results.json"
    
    main(directory, size_limit, output_file, previous_results_file)
