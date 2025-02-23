import socket
import threading
import time
import unittest

import anthropic
import requests

from mock_claude import app

class TestMockServer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Find an available port
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.bind(('', 0))
        cls.port = sock.getsockname()[1]
        sock.close()

        # Start server in a separate thread
        cls.server_thread = threading.Thread(
            target=app.run,
            kwargs={'port': cls.port, 'host': 'localhost'}
        )
        cls.server_thread.daemon = True
        cls.server_thread.start()
        
        # Give the server a moment to start
        time.sleep(1)
        
        # Base URL for requests
        cls.base_url = f'http://localhost:{cls.port}'

    def test_server_response(self):
        client = anthropic.Anthropic(
            base_url=self.base_url,
            api_key='no_key_for_mock',
        )

        expected = 'Hello! How can I help you today?'
        observed = []

        with client.messages.stream(
            max_tokens=1024,
            messages=[{"role": "user", "content": "Hello"}],
            model="claude-3-5-sonnet-20241022",
        ) as stream:
            for text in stream.text_stream:
                observed.append(text)

        self.assertEqual(''.join(observed), expected)

    @classmethod
    def tearDownClass(cls):
        #requests.get(f'{cls.base_url}/shutdown')
        cls.server_thread.join(timeout=1)

if __name__ == '__main__':
    unittest.main()
