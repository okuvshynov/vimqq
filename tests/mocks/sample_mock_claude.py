import anthropic

client = anthropic.Anthropic(
	base_url='http://127.0.0.1:5000'
)

with client.messages.stream(
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello"}],
    model="claude-3-5-sonnet-20241022",
) as stream:
  for text in stream.text_stream:
      print(text, end="", flush=True)
