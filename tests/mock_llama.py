import argparse
from flask import Flask, request, Response
import json
import logging
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

# for now mock server returns three pieces of content(for streamed requests):
# "BEGIN"
# COPY_OF_REQUEST
# "END"
@app.route('/v1/chat/completions', methods=['POST'])
def stream_response():
    # Get the JSON data from the POST request
    input_data = request.json
    do_stream = input_data['stream']
    question = input_data['messages'][-1]['content']
    logging.info(f'QUERY: {question}')

    if do_stream:
        def generate():
            response_data = {
                "choices": [{"delta": {"content" : 'BEGIN\n'}}],
            }
            yield f"data: {json.dumps(response_data)}\n\n"

            time.sleep(0.5)
            response_data = {
                "choices": [{"delta": {"content" : f'{question}\n'}}],
            }
            yield f"data: {json.dumps(response_data)}\n\n"

            time.sleep(0.5)
            response_data = {
                "choices": [{"delta": {"content" : 'END\n'}}],
            }
            yield f"data: {json.dumps(response_data)}\n\n"

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
    parser.add_argument('--logs', help='directory for log files')
    args = parser.parse_args()
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s %(levelname)s: %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
        handlers=[
            logging.FileHandler(f'{args.logs}/mock_serv.log'),
            logging.StreamHandler()
        ]
    )
    logging.info(f'starting on port {args.port}')
    app.run(debug=True, port=args.port)
