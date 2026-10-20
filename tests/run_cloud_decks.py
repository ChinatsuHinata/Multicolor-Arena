"""Exercise private deck sync through real loopback account and relay services."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "relay"))
import account_store as accounts

godot = root / ".godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe"
scratch = root / "work/cloud-decks"
scratch.mkdir(parents=True, exist_ok=True)
flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0


def ready(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
            return True
    except OSError:
        return False


if ready(48057) or ready(48058):
    raise SystemExit("Loopback test ports 48057 and 48058 must be unused.")

with tempfile.TemporaryDirectory(prefix="TEST_ONLY_", dir=scratch) as temp:
    database = Path(temp) / "players.sqlite3"
    conn = accounts.database(database)
    clients = []
    for username, platform, device in (("TEST_cloud", "pc", "a"), ("TEST_cloud", "android", "b"), ("TEST_other", "pc", "c")):
        payload = dict(username=username, platform=platform, device=device * 32, password="password123!")
        if platform == "pc":
            assert accounts.handle(conn, dict(payload, action="register"))["ok"]
        login = accounts.handle(conn, dict(payload, action="login"))
        assert login["ok"], login
        clients.append(dict(username=username, token=login["token"]))
    conn.close()
    manifest = Path(temp) / "clients.json"
    manifest.write_text(json.dumps(dict(endpoint="ws://127.0.0.1:48057", clients=clients)), encoding="utf-8")
    services = []
    try:
        with (scratch / "services.log").open("w", encoding="utf-8") as log:
            services.append(subprocess.Popen([sys.executable, "relay/account_store.py", "--database", str(database), "--port", "48058"], cwd=root, stdout=log, stderr=log, creationflags=flags))
            services.append(subprocess.Popen([str(godot), "--headless", "--path", "relay", "--log-file", str(scratch / "relay.log"), "--script", "server.gd", "--", "--bind", "127.0.0.1", "--port", "48057", "--transport", "websocket", "--account-port", "48058"], cwd=root, stdout=log, stderr=log, creationflags=flags))
            deadline = time.monotonic() + 12
            while not (ready(48057) and ready(48058)):
                if time.monotonic() > deadline or any(process.poll() is not None for process in services):
                    raise RuntimeError(f"Test services failed; see {scratch / 'services.log'}")
                time.sleep(0.1)
            command = [str(godot), *([] if "--render" in sys.argv else ["--headless"]), "--path", ".", "--log-file", str(scratch / "test.log"), "--script", "tests/test_cloud_decks.gd", "--", str(manifest)]
            result = subprocess.run(command, cwd=root, capture_output=True, encoding="utf-8", errors="replace", timeout=150, creationflags=flags)
            print(result.stdout, end="")
            print(result.stderr, end="")
            raise SystemExit(result.returncode)
    finally:
        for process in services:
            process.terminate()
        for process in services:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
