import argparse
import json
import time

from flask import Flask, request, Response

app = Flask(__name__)

def stream_event(event_type, data):
    """Helper function to format SSE events"""
    return f"event: {event_type}\ndata: {json.dumps(data)}\n\n"

def create_message_start(message_id):
    """Create initial message start event"""
    return {
        "type": "message_start",
        "message": {
            "id": message_id,
            "type": "message",
            "role": "assistant",
            "content": [],
            "model": "claude-3-5-sonnet-20241022",
            "stop_reason": None,
            "stop_sequence": None,
            "usage": {"input_tokens": 25, "output_tokens": 1}
        }
    }

def stream_text_content(text, index=0):
    """Stream a text content block"""
    yield stream_event("content_block_start", {
        "type": "content_block_start",
        "index": index,
        "content_block": {"type": "text", "text": ""}
    })
    
    # Simulate realistic streaming by splitting text into smaller chunks
    words = text.split()
    current_chunk = ""
    
    for word in words:
        current_chunk += word
        if word != words[-1]:
            current_chunk += " "
        if len(current_chunk) >= 10 or word == words[-1]:
            yield stream_event("content_block_delta", {
                "type": "content_block_delta",
                "index": index,
                "delta": {"type": "text_delta", "text": current_chunk}
            })
            current_chunk = ""
            time.sleep(0.1)  # Simulate network delay
    
    yield stream_event("content_block_stop", {
        "type": "content_block_stop",
        "index": index
    })

def stream_message_end(stop_reason="end_turn"):
    """Stream message ending events"""
    yield stream_event("message_delta", {
        "type": "message_delta",
        "delta": {"stop_reason": stop_reason, "stop_sequence": None},
        "usage": {"output_tokens": 15}
    })
    
    yield stream_event("message_stop", {
        "type": "message_stop"
    })

# Predefined responses
RESPONSES = {
    "single_text": {
        "content": "Hello! How can I help you today?",
        "stop_reason": "end_turn"
    },
}

@app.route('/v1/messages', methods=['POST'])
def stream_response():
    data = request.get_json()
    print(data)
    if not data.get('stream', False):
        return {"error": "This endpoint only supports streaming responses"}, 400

    user_message = data['messages'][0]['content'].lower()
    
    def generate():
        # Start message
        yield stream_event("message_start", create_message_start(f"msg_{hash(user_message) % 1000000:06d}"))
        
        # Occasional ping
        yield stream_event("ping", {"type": "ping"})

        response = RESPONSES['single_text']
        
        yield from stream_text_content(response["content"])
            
        # End message
        yield from stream_message_end(response["stop_reason"])

    return Response(generate(), mimetype='text/event-stream')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run mock anthropic server')
    parser.add_argument('--port', type=int, help='Port to run the server on', required=True)
    args = parser.parse_args()
    app.run(debug=True, port=args.port)
