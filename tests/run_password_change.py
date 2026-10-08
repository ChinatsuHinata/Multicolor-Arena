"""Verify password changes through isolated loopback account and relay services."""
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

root = Path(__file__).resolve().parents[1]
godot = root / ".godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe"
scratch = root / "work/password-change-tests"
scratch.mkdir(parents=True, exist_ok=True)
creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
sys.path.insert(0, str(root / "relay"))
import account_store as store


def ready(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
            return True
    except OSError:
        return False


if ready(48055) or ready(48056):
    raise SystemExit("Test ports 48055 and 48056 must be unused.")

with tempfile.TemporaryDirectory(prefix="TEST_ONLY_", dir=scratch) as directory:
    services = []
    try:
        database_path = Path(directory) / "players.sqlite3"
        conn = store.database(database_path)
        payload = {"username": "TEST_ONLY_password_maxxx", "password": "\\" * 64, "device": "d" * 32}
        assert store.handle(conn, {"action": "register", **payload})["ok"]
        pc = store.handle(conn, {"action": "login", **payload})
        android = store.handle(conn, {"action": "login", **payload, "platform": "android"})
        original = conn.execute("SELECT password_salt,password_hash FROM players").fetchone()
        conn.close()
        with open(scratch / "services.log", "w", encoding="utf-8") as log:
            services.append(subprocess.Popen([sys.executable, "relay/account_store.py", "--database",
                str(database_path), "--port", "48056"], cwd=root,
                stdout=log, stderr=log, creationflags=creationflags))
            services.append(subprocess.Popen([str(godot), "--headless", "--path", "relay",
                "--log-file", str(scratch / "relay.log"), "--script", "res://server.gd", "--",
                "--bind", "127.0.0.1", "--port", "48055", "--transport", "websocket",
                "--account-port", "48056"], cwd=root,
                stdout=log, stderr=log, creationflags=creationflags))
            deadline = time.monotonic() + 15
            while not (ready(48055) and ready(48056)):
                if time.monotonic() > deadline or any(p.poll() is not None for p in services):
                    raise RuntimeError(f"Local test services failed to start; see {scratch / 'services.log'}")
                time.sleep(0.1)
            for script in ("test_account.gd", "test_password_change.gd"):
                args = ["--", "--server", "ws://127.0.0.1:48055"] if script == "test_account.gd" else []
                result = subprocess.run([str(godot), "--headless", "--path", ".",
                    "--log-file", str(scratch / f"{script}.log"), "--script", f"res://tests/{script}", *args],
                    cwd=root, creationflags=creationflags, timeout=90, capture_output=True,
                    encoding="utf-8", errors="replace")
                print(result.stdout, end="", flush=True)
                print(result.stderr, end="", flush=True)
                if result.returncode:
                    raise SystemExit(result.returncode)
            conn = store.database(database_path)
            changed = conn.execute("SELECT password_salt,password_hash FROM players WHERE username=?", (payload["username"],)).fetchone()
            assert changed != original and changed[0] != original[0]
            for session, platform in ((pc, "pc"), (android, "android")):
                assert not store.verify(conn, session["token"])["ok"]
                assert not store.handle(conn, {"action": "resume", "remember_token": session["remember_token"],
                    "device": payload["device"], "platform": platform})["ok"]
            assert not store.handle(conn, {"action": "login", **payload})["ok"]
            assert store.handle(conn, {"action": "login", **payload, "password": '"' * 64})["ok"]
            conn.close()
            print("PASS: database uses the new password and revokes both platforms' sessions and remembered credentials")
    finally:
        for service in reversed(services):
            service.terminate()
        for service in services:
            service.wait(timeout=10)
