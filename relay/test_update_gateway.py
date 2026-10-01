import socket
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

from update_gateway import Gateway, Handler


class GatewayTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        (root / "latest.json").write_bytes(b'{"signed":true}')
        (root / "1.2.7").mkdir()
        (root / "1.2.7" / "MulticolorArena-1.2.7-android.apk").write_bytes(b"0123456789")
        self.backend = socket.socket()
        self.backend.bind(("127.0.0.1", 0))
        self.backend.listen(1)
        self.gateway = Gateway(("127.0.0.1", 0), Handler, root, self.backend.getsockname())
        self.thread = threading.Thread(target=self.gateway.serve_forever, daemon=True)
        self.thread.start()
        self.base = f"http://127.0.0.1:{self.gateway.server_address[1]}"

    def tearDown(self):
        self.gateway.shutdown()
        self.gateway.server_close()
        self.backend.close()
        self.temp.cleanup()

    def test_manifest_and_range(self):
        with urllib.request.urlopen(self.base + "/updates/latest.json") as response:
            self.assertEqual(response.read(), b'{"signed":true}')
            self.assertEqual(response.headers["Cache-Control"], "no-store")
        url = self.base + "/updates/1.2.7/MulticolorArena-1.2.7-android.apk"
        with urllib.request.urlopen(urllib.request.Request(url, headers={"Range": "bytes=3-6"})) as response:
            self.assertEqual(response.status, 206)
            self.assertEqual(response.read(), b"3456")
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD")) as response:
            self.assertEqual(response.headers["Content-Length"], "10")
            self.assertEqual(response.read(), b"")

    def test_path_traversal_rejected(self):
        with self.assertRaises(urllib.error.HTTPError) as caught:
            urllib.request.urlopen(self.base + "/updates/1.2.7/../latest.json")
        self.assertEqual(caught.exception.code, 404)
        caught.exception.close()

    def test_websocket_bytes_are_forwarded(self):
        received = []

        def backend():
            connection, _ = self.backend.accept()
            with connection:
                received.append(connection.recv(4096))
                connection.sendall(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n\r\n")
                connection.sendall(connection.recv(4))

        worker = threading.Thread(target=backend)
        worker.start()
        with socket.create_connection(self.gateway.server_address) as client:
            client.settimeout(3)
            client.sendall(b"GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\n\r\n")
            self.assertIn(b"101 Switching Protocols", client.recv(4096))
            client.sendall(b"ping")
            self.assertEqual(client.recv(4), b"ping")
        worker.join(timeout=3)
        self.assertIn(b"Upgrade: websocket", received[0])


if __name__ == "__main__":
    unittest.main()
