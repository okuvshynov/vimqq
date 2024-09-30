# First step in the pipeline

# input (from stdin): query
# output: description of all changes in xml format

# this script assumes we have index to pass saved in .ll_index in the repo root

import json
import http.client
import logging
import os
import sys

from pathlib import Path

query_prompt="""
Provide your output as individual diff files I can apply with patch command without relying on version control system.
Provide your output in the following format:

<content>
<version>1</version>
<description>your plain text description of changes and motivation.</description>
<plan>Your detailed plan for implementing the changes. Provide enough details for reviewer to understand your changes</plan>
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

Here's high level summary of the project structure. To access the files content you MUST use provided tools.

"""

# Running main query which will return diff file
# can use tools, currently get_file
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

    # TODO: cache this
    messages = [{"role": "user", "content": query}]

    # max 5 iterations for now
    for i in range(5):
        # on first iteration we force tool use
        tool_choice = {"type": "auto"} if i > 0 else {"type": "any"}
        payload = json.dumps({
            "model": "claude-3-5-sonnet-20240620",
            "max_tokens": 8192,
            "tools": tools,
            "messages": messages,
            "tool_choice": tool_choice
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

        logging.info(f'received {i+1} reply from sonnet')
        logging.info(json.dumps(data['content']))
        
        messages.append({"role": "assistant", "content": data['content']})

        if data["stop_reason"] == "tool_use":
            message = {"role": "user", "content": []}
            for content_piece in data['content']:
                if content_piece['type'] == 'tool_use':
                    logging.info(f'requested tool: {content_piece["input"]}')
                    tool_use_id = content_piece['id']
                    tool_use_name = content_piece['name']
                    tool_use_args = content_piece['input']
                    if tool_use_name != 'get_file':
                        logging.info(f'unknown tool: {tool_use_name}')
                        continue
                    tool_result = get_files(git_root, tool_use_args['filepaths'])
                    message["content"].append({"type": "tool_result", "tool_use_id" : tool_use_id, "content": tool_result})
            messages.append(message)
        else:
            # got final reply
            return data['content']
    return None

def find_git_root(start_path='.'):
    current_path = Path(start_path).resolve()
    while current_path != current_path.parent:
        if (current_path / '.git').is_dir():
            return current_path
        current_path = current_path.parent
    logging.fatal("Not a git repository", file=sys.stderr)
    sys.exit(1)

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
    with open(os.path.join(git_root, '.ll_index'), 'r') as f:
        ll_index = f.read()

    logging.info(f'read index of size {len(ll_index)}')

    query = " ".join(sys.argv[1:])
    query_message = f'{query}\n{query_prompt}\n{ll_index}'

    logging.info(f'Running query')
    content = run_query(git_root, query_message, api_key)
    print(content[0]['text'])

if __name__ == '__main__':
    main()
