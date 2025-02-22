from flask import Flask, request, Response
import json
import time
import argparse

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

def stream_tool_use(tool_name, tool_input, index):
    """Stream a tool use content block"""
    tool_id = f"toolu_{hash(tool_name) % 1000000:06d}"
    
    yield stream_event("content_block_start", {
        "type": "content_block_start",
        "index": index,
        "content_block": {
            "type": "tool_use",
            "id": tool_id,
            "name": tool_name,
            "input": {}
        }
    })

    # Stream the input JSON in chunks
    input_json = json.dumps(tool_input)
    chunk_size = 10
    for i in range(0, len(input_json), chunk_size):
        chunk = input_json[i:i + chunk_size]
        yield stream_event("content_block_delta", {
            "type": "content_block_delta",
            "index": index,
            "delta": {"type": "input_json_delta", "partial_json": chunk}
        })
        time.sleep(0.1)

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
    "single_tool": {
        "tool_name": "get_weather",
        "tool_input": {"location": "San Francisco, CA"},
        "stop_reason": "tool_use"
    },
    "multiple_text": {
        "contents": [
            "Let me break this down into steps.",
            "First, we need to consider the basics.",
            "Finally, here's the conclusion."
        ],
        "stop_reason": "end_turn"
    },
    "multiple_tools": {
        "tools": [
            {
                "tool_name": "get_weather",
                "tool_input": {"location": "New York, NY"}
            },
            {
                "tool_name": "get_time",
                "tool_input": {"timezone": "America/New_York"}
            }
        ],
        "stop_reason": "tool_use"
    },
    "mixed": {
        "blocks": [
            {"type": "text", "content": "Let me check the weather for you."},
            {"type": "tool", "tool_name": "get_weather", "tool_input": {"location": "London, UK"}},
            {"type": "text", "content": "Now, let me check the time as well."},
            {"type": "tool", "tool_name": "get_time", "tool_input": {"timezone": "Europe/London"}}
        ],
        "stop_reason": "tool_use"
    }
}

@app.route('/v1/messages', methods=['POST'])
def stream_response():
    data = request.get_json()
    print(data)
    if not data.get('stream', False):
        return {"error": "This endpoint only supports streaming responses"}, 400

    # For demo purposes, choose response type based on the content of the first message
    user_message = data['messages'][0]['content'].lower()
    
    if "weather" in user_message:
        response_type = "single_tool"
    elif "multiple tools" in user_message:
        response_type = "multiple_tools"
    elif "multiple responses" in user_message:
        response_type = "multiple_text"
    elif "mixed" in user_message:
        response_type = "mixed"
    else:
        response_type = "single_text"

    def generate():
        # Start message
        yield stream_event("message_start", create_message_start(f"msg_{hash(user_message) % 1000000:06d}"))
        
        # Occasional ping
        yield stream_event("ping", {"type": "ping"})

        response = RESPONSES[response_type]
        
        if response_type == "single_text":
            yield from stream_text_content(response["content"])
            
        elif response_type == "single_tool":
            yield from stream_tool_use(response["tool_name"], response["tool_input"], 0)
            
        elif response_type == "multiple_text":
            for idx, content in enumerate(response["contents"]):
                yield from stream_text_content(content, idx)
                
        elif response_type == "multiple_tools":
            for idx, tool in enumerate(response["tools"]):
                yield from stream_tool_use(tool["tool_name"], tool["tool_input"], idx)
                
        elif response_type == "mixed":
            for idx, block in enumerate(response["blocks"]):
                if block["type"] == "text":
                    yield from stream_text_content(block["content"], idx)
                else:
                    yield from stream_tool_use(block["tool_name"], block["tool_input"], idx)

        # End message
        yield from stream_message_end(response["stop_reason"])

    return Response(generate(), mimetype='text/event-stream')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run mock anthropic server')
    parser.add_argument('--port', type=int, help='Port to run the server on', required=True)
    args = parser.parse_args()
    app.run(debug=True, port=args.port)
