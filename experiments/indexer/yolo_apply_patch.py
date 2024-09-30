import json
import logging
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

from pathlib import Path

import http.client

def apply_patch(root, path, patch_content, api_key):
    # Change to the root directory
    os.chdir(root)
    
    try:
        # Run the patch command
        result = subprocess.run(['patch', path], input=patch_content, text=True, capture_output=True, check=True)
        logging.info("Patch applied successfully")
        return
    except subprocess.CalledProcessError as e:
        logging.error("Error applying patch.")

    logging.info("Trying fuzzy patch")
    with open(path, 'r') as f:
        file_content = f.read()

    patched = fuzzy_patch(file_content, patch_content, api_key)
    with open(path, 'w') as f:
        f.write(patched)

sys_prompt="You are helpful and attentive to details assistant"

patch_prompt="""
You are given file content in tags <file></file> and patch file in tags <patch></patch>. Patch file might have line numbers off, your job is to perform fuzzy merging of that patch. Take into account line numbers, context around the change, +/- signs. Put the merged content in <file_new></file_new> tags.

After completing the job, look back at merged file you created and verify that your merged version is correct. If you see any issues, fix them and show the new merged content in <file_fixed></file_fixed> tags.

"""

def query_claude(message):
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY environment variable is not set")
    req = {
        "max_tokens": 4096,
        "model": "claude-3-5-sonnet-20240620",
        "messages": [
            {"role": "user", "content": message}
        ]
    }
    payload = json.dumps(req)
    headers = {
        'x-api-key': api_key,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json'
    }
    conn = http.client.HTTPSConnection("api.anthropic.com")

    conn.request("POST", "/v1/messages", payload, headers)
    res = conn.getresponse()
    data = res.read()
    data = json.loads(data.decode("utf-8"))
    return data['content'][0]['text']

def query_groq(message):
    req = {
        "max_tokens": 4096,
        "model": "llama-3.1-70b-versatile",
        "messages": [
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": message}
        ]
    }
    payload = json.dumps(req)

    # Get the path to the current Python script
    script_dir = os.path.dirname(__file__)

    # Construct the path to the query_groq.sh script
    script_path = os.path.join(script_dir, 'query_groq.sh')

    process = subprocess.Popen([script_path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, error = process.communicate(payload.encode())

    if error:
        logging.error(f"Error: {error.decode()}")
        return None

    data = json.loads(output.decode())
    return data['choices'][0]['message']['content']

def fuzzy_patch(file_content, patch_content, api_key):
    message = f'{patch_prompt}<file>{file_content}</file>\n<patch>{patch_content}</patch>'

    content = query_groq(message)

    file_new_matches = list(re.finditer(r'<file_new>(.*?)</file_new>', content, re.DOTALL))
    
    if not file_new_matches:
        raise ValueError("Could not find any <file_new> tag in the file")

    file_new = file_new_matches[-1].group(1)

    file_fixed_matches = list(re.finditer(r'<file_fixed>(.*?)</file_fixed>', content, re.DOTALL))
    
    if not file_fixed_matches:
        return file_new
    return file_fixed_matches[-1].group(1)

def find_git_root(start_path='.'):
    current_path = Path(start_path).resolve()
    while current_path != current_path.parent:
        if (current_path / '.git').is_dir():
            return current_path
        current_path = current_path.parent
    logging.info("Not a git repository", file=sys.stderr)
    sys.exit(1)

def main():
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s %(levelname)s: %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
        handlers=[
            logging.StreamHandler()
        ]
    )
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY environment variable is not set")
    git_root = find_git_root()

    if not sys.stdin.isatty():
        content = sys.stdin.read()
    else:
        # If no pipe input, check for file arguments
        if len(sys.argv) > 1:
            try:
                with open(sys.argv[1], 'r', encoding='utf-8') as file:
                    content = file.read()
            except FileNotFoundError:
                logging.info(f"Error: File '{sys.argv[1]}' not found.", file=sys.stderr)
                sys.exit(1)
        else:
            logging.info("Error: No input provided. Use a pipe or provide a filename.", file=sys.stderr)
            sys.exit(1)
    for fstr in content.strip('\n').split('\n'):
        try:
            f = json.loads(fstr)
        except:
            logging.error(f'unable to parse {fstr}')
            continue
        path = f['path']
        patch = f['patch']
        logging.info(f'processing patch for {path}')
        apply_patch(git_root, path, patch, api_key)

if __name__ == '__main__':
    main()
