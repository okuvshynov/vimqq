import argparse
import json
import logging
import signal
import sys

from collections import defaultdict
from flask import Flask, request, Response

should_exit = False

stats = defaultdict(int)

def signal_handler(sig, frame):
    global should_exit
    print('Received shutdown signal, exiting...')
    should_exit = True
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

app = Flask(__name__)

@app.route('/alive', methods=['GET'])
def alive():
    return Response('alive', content_type='text/plain')

@app.route('/reset', methods=['GET'])
def reset_stats():
    global stats
    stats.clear()
    return Response('alive', content_type='text/plain')

@app.route('/stats', methods=['GET'])
def get_stats():
    global stats
    return Response(json.dumps(stats), content_type='application/json')

# for now mock server returns three pieces of content(for streamed requests):
# "BEGIN"
# COPY_OF_REQUEST
# "END"
@app.route('/v1/chat/completions', methods=['POST'])
def chat():
    global stats
    stats['n_chat_queries'] += 1
    # Get the JSON data from the POST request
    input_data = request.json
    do_stream = input_data['stream']
    is_warmup = False
    if 'n_predict' in input_data:
        n_predict = input_data['n_predict']
        if n_predict == 0:
            is_warmup = True

    question = input_data['messages'][-1]['content'][0]['text']
    logging.info(f'QUERY: {question}')
    logging.info(f'is_warmup: {is_warmup}')

    if is_warmup:
        stats['n_warmups'] += 1
        response_data = { "choices": [{"message": {"content": ""}}]}
        return Response(json.dumps(response_data), content_type='application/json')

    if do_stream:
        stats['n_stream_queries'] += 1
        def generate():
            response_data = {
                "choices": [{"delta": {"content" : 'BEGIN\n'}}],
            }
            yield f"data: {json.dumps(response_data)}\n\n"
            stats['n_deltas'] += 1

            response_data = {
                "choices": [{"delta": {"content" : f'{question}\n'}}],
            }
            yield f"data: {json.dumps(response_data)}\n\n"
            stats['n_deltas'] += 1

            response_data = {
                "choices": [{"delta": {"content" : 'END\n'}}],
            }
            yield f"data: {json.dumps(response_data)}\n\n"
            stats['n_deltas'] += 1

            yield "data: [DONE]"

        return Response(generate(), content_type='text/event-stream')
    else:
        stats['n_non_stream_queries'] += 1
        # Return a single JSON response - we use non-streaming for title requests
        # let's return something like len=len(question)
        response_data = {
            "choices": [{"message": {"content": f"l={len(question)}"}}],
        }
        return Response(json.dumps(response_data), content_type='application/json')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run mock llama server')
    parser.add_argument('--port', type=int, help='Port to run the server on', required=True)
    parser.add_argument('--logs', help='directory for log files', required=True)
    args = parser.parse_args()
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s %(levelname)s: %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
        handlers=[
            logging.FileHandler(f'{args.logs}/mock_server.log'),
            logging.StreamHandler()
        ]
    )
    logging.info(f'starting on port {args.port}')
    app.run(debug=True, port=args.port)
