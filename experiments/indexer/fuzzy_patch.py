import json
import re
import sys

import http.client
import urllib.parse

sys_prompt="You are helpful and attentive to details assistant"

query_prompt="""
You are given file content in tags <file></file> and patch file in tags <patch></patch>. Patch file might have line numbers off, your job is to perform fuzzy merging of that patch. Take into account line numbers, context around the change, +/- signs. Put the merged content in <file_new></file_new> tags.

After completing the job, look back at merged file you created and verify that your merged version is correct. If you see any issues, fix them and show the new merged content in <file_fixed></file_fixed> tags.

"""

def fuzzy_patch(file_content, patch_content):
    message = f'{query_prompt}<file>{file_content}</file>\n<patch>{patch_content}</patch>'
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
    with open(sys.argv[1], 'r') as f:
        file_content = f.read()
    with open(sys.argv[2], 'r') as f:
        patch_content = f.read()
    print(fuzzy_patch(file_content, patch_content))

if __name__ == '__main__':
    main()
