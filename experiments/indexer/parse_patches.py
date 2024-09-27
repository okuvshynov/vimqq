import os
import sys
import argparse
import fnmatch
import json
import re
import xml.etree.ElementTree as ET

from pathlib import Path
from xml.dom import minidom
import xml.etree.ElementTree as ET

import http.client
import urllib.parse

def parse_patch_xml(content):
    content_match = re.search(r'<content>(.*?)</content>', content, re.DOTALL)
    
    if not content_match:
        raise ValueError("Could not find complete <content> tag in the file")

    # Extract the parts
    pre_content = content[:content_match.start()].strip()
    xml_content = content_match.group(1)
    post_content = content[content_match.end():].strip()

    # Parse file information using regex
    file_pattern = r'<file>\s*<path>\s*(.*?)\s*</path>\s*<patch>\s*(.*?)\s*</patch>\s*</file>'
    files = [
        {'path': match.group(1), 'patch': match.group(2)}
        for match in re.finditer(file_pattern, xml_content, re.DOTALL)
    ]

    # Return a dictionary with all parts
    return files

def main():
    with open('/tmp/patch_title', 'r') as f:
        reply = f.read()

    reply = json.loads(reply)
    #print(reply[0]['text'])
    for f in parse_file(reply[0]['text']):
        print(f"File path: {f['path']}")
        print(f"Patch: {f['patch']}")
        print("---")

if __name__ == '__main__':
    main()

