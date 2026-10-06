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
        (root / "pck" / "1.2.7.2").mkdir(parents=True)
        (root / "pck" / "latest.json").write_bytes(b'{"pck":true}')
        (root / "pck" / "chain.json").write_bytes(b'{"chain":true}')
        (root / "pck" / "1.2.7.2" / "MulticolorArena-1.2.7.1-to-1.2.7.2-windows.pck").write_bytes(b"PATCH")
        self.backend = socket.socket()
        self.backend.bind(("127.0.0.1", 0))
        self.backend.listen(1)
        self.gateway = Gateway(("127.0.0.1", 0), Handler, root, self.backend.getsockname())
        # Join active file transfers before TemporaryDirectory cleanup on Windows.
        self.gateway.daemon_threads = False
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

    def test_pck_manifest_and_asset(self):
        with urllib.request.urlopen(self.base + "/updates/pck/latest.json") as response:
            self.assertEqual(response.read(), b'{"pck":true}')
            self.assertEqual(response.headers["Cache-Control"], "no-store")
        url = self.base + "/updates/pck/1.2.7.2/MulticolorArena-1.2.7.1-to-1.2.7.2-windows.pck"
        with urllib.request.urlopen(url) as response:
            self.assertEqual(response.read(), b"PATCH")
        with self.assertRaises(urllib.error.HTTPError) as caught:
            urllib.request.urlopen(self.base + "/updates/pck/1.2.7.3/MulticolorArena-1.2.7.1-to-1.2.7.2-windows.pck")
        self.assertEqual(caught.exception.code, 404)
        caught.exception.close()

    def test_chain_manifest_incremental_assets_and_replacement_cache(self):
        with urllib.request.urlopen(self.base + "/updates/pck/chain.json") as response:
            self.assertEqual(response.read(), b'{"chain":true}')
            self.assertEqual(response.headers["Cache-Control"], "no-store")
        version_dir = self.gateway.release_root / "pck" / "1.2.7.3"
        version_dir.mkdir()
        name = "MulticolorArena-1.2.7.2-to-1.2.7.3-android-" + "a" * 64 + ".pck"
        (version_dir / name).write_bytes(b"INCREMENTAL")
        url = self.base + "/updates/pck/1.2.7.3/" + name
        with urllib.request.urlopen(urllib.request.Request(url, headers={"Range": "bytes=0-2"})) as response:
            self.assertEqual(response.status, 206)
            self.assertEqual(response.read(), b"INC")
            self.assertIn("immutable", response.headers["Cache-Control"])
        legacy_url = self.base + "/updates/pck/1.2.7.2/MulticolorArena-1.2.7.1-to-1.2.7.2-windows.pck"
        with urllib.request.urlopen(legacy_url) as response:
            self.assertEqual(response.headers["Cache-Control"], "no-store")
        with self.assertRaises(urllib.error.HTTPError) as caught:
            urllib.request.urlopen(url.replace("a" * 64, "not-a-hash"))
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
