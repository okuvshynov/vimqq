#!/usr/bin/env python3

import os
import sys
import argparse
import fnmatch
import json
import xml.etree.ElementTree as ET
import subprocess
import os
import tempfile
import re

from pathlib import Path
from xml.dom import minidom

import http.client
import urllib.parse

query_prompt="""
Let's extract the title generation query construction from each bot implementation and use the same code for each bot.
Provide your output as individual diff files I can apply with patch command without relying on version control system.
Provide your output in the following format:

<content>
<version>1</version>
<description>your plain text description of changes and motivation</description>
<files>
<file>
    path>path/filename</path>
    <patch>diff to apply</patch>
</file>
...
<file>
    <path>path/filename</path>
    <patch>diff to apply</patch>
</file>
</files>
</content>

After you have completed this task, there's a required validation step. Your job is to try to apply these patches and verify they would apply cleanly. Make sure line numbers in the patch are correct. 

If any modification is needed, provide another copy of <content>...</content> output with version incremented by one.

Repeat this process until you are confident the patches would apply cleanly and work as expected.

Here's high level summary of the project structure, please use the provided tools to get needed information.

"""

example_reply="""
{'id': 'msg_01PaUSfesGdfb33SJMsBrBzf', 'type': 'message', 'role': 'assistant', 'model': 'claude-3-5-sonnet-20240620', 'content': [{'type': 'text', 'text': "To extract common functionality from all the bots defined in this project, I'll need to examine the
 bot-specific files and the main bot management file. Let's start by looking at the contents of these files."}, {'type': 'tool_use', 'id': 'toolu_01BYVnqXSyoEa4L69CQuxG8X', 'name': 'get_file', 'input': {'filepaths': ['autoload/vimqq/bots/bots.vim', 'autol
oad/vimqq/bots/claude.vim', 'autoload/vimqq/bots/groq.vim', 'autoload/vimqq/bots/mistral.vim', 'autoload/vimqq/bots/llama.vim']}}], 'stop_reason': 'tool_use', 'stop_sequence': None, 'usage': {'input_tokens': 4653, 'output_tokens': 182}}
"""

def run_query(git_root, query, api_key):
    conn = http.client.HTTPSConnection("api.anthropic.com")

    tools = [{
            "name": "get_file",
            "description": "Gets content of one or more files returned as a single string.",
            "input_schema": {
              "type": "object",
              "properties": {
                "filepaths": {
                  "type": "array",
                  "items": {
                    "type": "string"
                  },
                  "description": "A list of file paths to get the content."
                }
              },
              "required": ["filepaths"]
            }
    }]

    messages = [{"role": "user", "content": query}]

    # max 5 iterations for now
    for i in range(5):
        payload = json.dumps({
            "model": "claude-3-5-sonnet-20240620",
            "max_tokens": 8192,
            "tools": tools,
            "messages": messages,
        })
        
        headers = {
            'x-api-key': api_key,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json'
        }
        
        conn.request("POST", "/v1/messages", payload, headers)
        
        res = conn.getresponse()
        data = res.read()
        data = json.loads(data.decode("utf-8"))

        print('received reply from sonnet')
        #print(json.dumps(data['content']))
        
        messages.append({"role": "assistant", "content": data['content']})

        if data["stop_reason"] == "tool_use":
            message = {"role": "user", "content": []}
            for content_piece in data['content']:
                if content_piece['type'] == 'tool_use':
                    print(f'requested tool: {content_piece["input"]}')
                    tool_use_id = content_piece['id']
                    tool_use_name = content_piece['name']
                    tool_use_args = content_piece['input']
                    if tool_use_name != 'get_file':
                        print(f'unknown tool: {tool_use_name}')
                        continue
                    tool_result = get_files(git_root, tool_use_args['filepaths'])
                    message["content"].append({"type": "tool_result", "tool_use_id" : tool_use_id, "content": tool_result})
            messages.append(message)
        else:
            # got final reply
            return data['content']
    return None

def get_files(git_root, rel_paths):
    res = []
    for p in rel_paths:
        file_path = os.path.join(git_root, p)
        if os.path.exists(file_path):
            with open(file_path, 'r') as f:
                res.append('\n')
                res.append(p)
                res.append(f.read())
        else:
            res.append('\n')
            res.append(p)
            res.append('!! This file was not found. Probably you are still working on it.')

    return "\n".join(res)

def find_git_root(start_path='.'):
    current_path = Path(start_path).resolve()
    while current_path != current_path.parent:
        if (current_path / '.git').is_dir():
            return current_path
        current_path = current_path.parent
    print("Not a git repository", file=sys.stderr)
    sys.exit(1)

def parse_patch_xml(content):
    # Find all <content> blocks
    content_matches = list(re.finditer(r'<content>(.*?)</content>', content, re.DOTALL))
    
    if not content_matches:
        raise ValueError("Could not find any <content> tag in the file")

    # Get the last <content> block
    last_content_match = content_matches[-1]

    # Extract the parts
    pre_content = content[:last_content_match.start()].strip()
    xml_content = last_content_match.group(1)
    post_content = content[last_content_match.end():].strip()

    # Parse file information using regex
    file_pattern = r'<file>\s*<path>\s*(.*?)\s*</path>\s*<patch>\s*(.*?)\s*</patch>\s*</file>'
    files = [
        {'path': match.group(1), 'patch': match.group(2)}
        for match in re.finditer(file_pattern, xml_content, re.DOTALL)
    ]

    # Return a dictionary with all parts
    return files

# TODO: we need to do fuzzy patch if normal patch fails
def apply_patch(root, path, patch_content):
    # Change to the root directory
    os.chdir(root)
    
    try:
        # Run the patch command
        result = subprocess.run(['patch', path], input=patch_content, text=True, capture_output=True, check=True)
        print("Patch applied successfully")
        print("Stdout:", result.stdout)
        return
    except subprocess.CalledProcessError as e:
        print("Error applying patch:")
        print("Stdout:", e.stdout)
        print("Stderr:", e.stderr)

    print("Trying fuzzy patch")
    with open(path, 'r') as f:
        file_content = f.read()

    patched = fuzzy_patch(file_content, patch_content)
    with open(path, 'w') as f:
        f.write(patched)



sys_prompt="You are helpful and attentive to details assistant"

patch_prompt="""
You are given file content in tags <file></file> and patch file in tags <patch></patch>. Patch file might have line numbers off, your job is to perform fuzzy merging of that patch. Take into account line numbers, context around the change, +/- signs. Put the merged content in <file_new></file_new> tags.

After completing the job, look back at merged file you created and verify that your merged version is correct. If you see any issues, fix them and show the new merged content in <file_fixed></file_fixed> tags.

"""

def fuzzy_patch(file_content, patch_content):
    message = f'{patch_prompt}<file>{file_content}</file>\n<patch>{patch_content}</patch>'
    req = {
        "n_predict": 8192,
        "stream": False,
        "cache_prompt": True,
        "messages": [
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": message}
        ]
    }
    conn = http.client.HTTPConnection("localhost", 8080)
    payload = json.dumps(req)
    headers = {
        'content-type': 'application/json'
    }
    conn.request("POST", "/v1/chat/completions", payload, headers)
    res = conn.getresponse()
    data = res.read()
    data = json.loads(data.decode("utf-8"))
    content = data['choices'][0]['message']['content']

    file_new_matches = list(re.finditer(r'<file_new>(.*?)</file_new>', content, re.DOTALL))
    
    if not file_new_matches:
        raise ValueError("Could not find any <file_new> tag in the file")

    file_new = file_new_matches[-1].group(1)

    file_fixed_matches = list(re.finditer(r'<file_fixed>(.*?)</file_fixed>', content, re.DOTALL))
    
    if not file_fixed_matches:
        return file_new
    return file_fixed_matches[-1].group(1)

def main():
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY environment variable is not set")
    git_root = find_git_root()
    with open(os.path.join(git_root, '.ll_index'), 'r') as f:
        ll_index = f.read()

    print(f'read index of size {len(ll_index)}')

    query_message = query_prompt + ll_index

    print(f'Running query')
    content = run_query(git_root, query_message, api_key)
    patches = parse_patch_xml(content[0]['text'])
    print(f'Received {len(patches)} patches')
    for f in patches:
        path = f['path']
        patch = f['patch']
        print(f'processing patch for {path}')
        apply_patch(git_root, path, patch)

if __name__ == '__main__':
    main()
