#!/usr/bin/env python3

import os
import sys
import argparse
import fnmatch
import json
import xml.etree.ElementTree as ET

from pathlib import Path
from xml.dom import minidom

import http.client
import urllib.parse

index_prompt="""
You will be given content for multiple files from code repository. It will be formatted as a list of entries like this:

<input_file>
<index>1</index>
<path>path/filename</path>
<content>
Content here....
</content>
</input_file>

index is just a number from 1 to N where N is the number of input files.

Your job is to provide a description of each provided file.
Description for each file should be detailed, contain both high level description and every important detail.

For every file in the input, write output in the following format:

<file>
<index>1</index>
<path>path/filename</path>
<summary>
Summary here...
</summary>
</file>

Make sure you processed all files and kept original index for each file.

===========================================================

"""

def run_index_query(query, api_key):
    conn = http.client.HTTPSConnection("api.anthropic.com")
    
    payload = json.dumps({
        "model": "claude-3-5-sonnet-20240620",
        "max_tokens": 8192,
        "messages": [{"role": "user", "content": query}]
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

    return data['content'][0]['text']


def process_file(filepath, relative_path, index):
    file_element = ET.Element("file")
    
    index_element = ET.SubElement(file_element, "index")
    index_element.text = str(index)
    
    name_element = ET.SubElement(file_element, "name")
    name_element.text = str(relative_path)
    
    content_element = ET.SubElement(file_element, "content")
    
    try:
        with open(filepath, 'r', encoding='utf-8') as file:
            content_element.text = file.read()
    except Exception as e:
        content_element.text = f"Error reading file: {str(e)}"
    
    xml_string = minidom.parseString(ET.tostring(file_element)).toprettyxml(indent="  ")
    return xml_string

def find_git_root(start_path='.'):
    current_path = Path(start_path).resolve()
    while current_path != current_path.parent:
        if (current_path / '.git').is_dir():
            return current_path
        current_path = current_path.parent
    print("Not a git repository", file=sys.stderr)
    sys.exit(1)

def list_files(root_path, patterns):
    res = []
    for root, _, files in os.walk(root_path):
        for file in files:
            file_path = Path(root) / file
            relative_path = file_path.relative_to(root_path)
            if any(fnmatch.fnmatch(file, pattern) for pattern in patterns):
                res.append(process_file(file_path, relative_path, len(res) + 1))
    return res

def main():
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY environment variable is not set")
    parser = argparse.ArgumentParser(description="List files in a Git repository matching specified patterns.")
    parser.add_argument('--patterns', default='*.txt,*.py,*.cpp', help='Comma-separated list of file patterns (default: %(default)s)')
    args = parser.parse_args()

    patterns = args.patterns.split(',')
    git_root = find_git_root()
    file_entries = list_files(git_root, patterns)

    index_message = index_prompt + ''.join(file_entries)

    reply = run_index_query(index_message, api_key)
    with open(os.path.join(git_root, '.ll_index'), 'w') as f:
        f.write(reply)

if __name__ == '__main__':
    main()
