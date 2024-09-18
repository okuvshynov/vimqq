import argparse
from flask import Flask, request, Response
import json
import signal
import sys
import time

should_exit = False

def signal_handler(sig, frame):
    global should_exit
    print('Received shutdown signal, exiting...')
    should_exit = True
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

app = Flask(__name__)

@app.route('/v1/chat/completions', methods=['POST'])
def stream_response():
    # Get the JSON data from the POST request
    input_data = request.json
    do_stream = input_data['stream']
    print(input_data)
    print(do_stream)

    if do_stream:
        def generate():
            for i in range(5):
                response_data = {
                    "choices": [{"delta": {"content" : f'{i}'}}],
                }
                
                yield f"data: {json.dumps(response_data)}\n\n"
                time.sleep(1)

        return Response(generate(), content_type='text/event-stream')
    else:
        # Return a single JSON response
        response_data = {
            "choices": [{"message": {"content": "one-two-three"}}],
        }
        return Response(json.dumps(response_data), content_type='application/json')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run mock llama server')
    parser.add_argument('--port', type=int, help='Port to run the server on', required=True)
    args = parser.parse_args()
    app.run(debug=True, port=args.port)
