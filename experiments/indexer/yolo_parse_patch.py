import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

from pathlib import Path
from xml.dom import minidom

import http.client
import urllib.parse

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

def main():
    if not sys.stdin.isatty():
        content = sys.stdin.read()
    else:
        # If no pipe input, check for file arguments
        if len(sys.argv) > 1:
            try:
                with open(sys.argv[1], 'r', encoding='utf-8') as file:
                    content = file.read()
            except FileNotFoundError:
                print(f"Error: File '{sys.argv[1]}' not found.", file=sys.stderr)
                sys.exit(1)
        else:
            print("Error: No input provided. Use a pipe or provide a filename.", file=sys.stderr)
            sys.exit(1)
    patches = parse_patch_xml(content)
    for patch in patches:
        print(json.dumps(patch))

if __name__ == '__main__':
    main()
