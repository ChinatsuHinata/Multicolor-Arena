"""Check transparent forwarding and which socket actually closes at the gateway."""
import contextlib
import io
import json
from pathlib import Path
import socket
import sys
import tempfile
import threading
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
from update_gateway import Gateway, Handler


class GatewayEvidenceTests(unittest.TestCase):
    def test_both_closing_directions_preserve_forwarding(self):
        for closer in ("client", "backend"):
            with self.subTest(closer=closer), tempfile.TemporaryDirectory(prefix="TEST_ONLY_gateway_") as temp:
                output = io.StringIO()
                finished = threading.Event()
                class RecordingHandler(Handler):
                    def handle(self):
                        try:
                            super().handle()
                        finally:
                            finished.set()
                with socket.socket() as listener, contextlib.redirect_stdout(output):
                    listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(5)
                    with Gateway(("127.0.0.1", 0), RecordingHandler, temp, listener.getsockname()) as server:
                        worker = threading.Thread(target=server.serve_forever, daemon=True); worker.start()
                        try:
                            with socket.create_connection(server.server_address, timeout=5) as client:
                                client.sendall(b"GET / HTTP/1.1\r\nUpgrade: websocket\r\n\r\n")
                                backend, _ = listener.accept()
                                with backend:
                                    backend.settimeout(5)
                                    self.assertIn(b"Upgrade: websocket", backend.recv(4096))
                                    client.sendall(b"client-game-payload")
                                    self.assertEqual(backend.recv(4096), b"client-game-payload")
                                    backend.sendall(b"server-game-payload")
                                    self.assertEqual(client.recv(4096), b"server-game-payload")
                                    (client if closer == "client" else backend).shutdown(socket.SHUT_WR)
                                    self.assertTrue(finished.wait(5))
                        finally:
                            server.shutdown(); worker.join(5)
                records = [json.loads(line.removeprefix("gateway_event ")) for line in output.getvalue().splitlines()]
                self.assertEqual([r["event"] for r in records], ["websocket_open", "websocket_closed"])
                self.assertEqual(records[1]["cause"], closer + "_eof")
                self.assertGreater(records[1]["backend_port"], 0)
                self.assertEqual(records[1]["up_bytes"], len(b"client-game-payload"))
                self.assertNotIn("payload", output.getvalue())


if __name__ == "__main__":
    unittest.main()
