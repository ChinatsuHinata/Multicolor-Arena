"""Run the current matchmaking integration against isolated loopback services."""
import os
from pathlib import Path
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time

root = Path(__file__).resolve().parents[1]
godot = root / ".godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe"
scratch = root / "work/cloud-matchmaking"
scratch.mkdir(parents=True, exist_ok=True)
creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0

def ready(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
            return True
    except OSError:
        return False

if ready(48045) or ready(48046):
    raise SystemExit("Test ports 48045 and 48046 must be unused.")

with tempfile.TemporaryDirectory(prefix="TEST_ONLY_", dir=scratch) as temp:
    services = []
    try:
        simulation = "--simulation-only" in sys.argv
        log_prefix = "simulation-" if simulation else "rooms-" if "--rooms-only" in sys.argv else ""
        database_path = Path(temp) / "players.sqlite3"
        if simulation:
            sys.path.insert(0, str(root / "relay"))
            import account_store
            conn = account_store.database(database_path)
            players = []
            for index, rating in enumerate((1000, 1080, 1010, 1170, 1400, 1600, 1000)):
                payload = {"username": f"TEST_ONLY_sim_{index}", "password": "password123!", "device": "d" * 32}
                assert account_store.handle(conn, {"action": "register", **payload})["ok"]
                conn.execute("UPDATE players SET elo=? WHERE username=?", (rating, payload["username"]))
                conn.commit()
                login = account_store.handle(conn, {"action": "login", **payload})
                assert login["ok"]
                players.append({"token": login["token"], "nickname": login["nickname"], "elo": login["elo"]})
            conn.close()
            import json
            manifest = Path(temp) / "clients.json"
            manifest.write_text(json.dumps({"endpoint": "ws://127.0.0.1:48045", "players": players}), encoding="utf-8")
        with open(scratch / f"{log_prefix}services.log", "w", encoding="utf-8") as log:
            services.append(subprocess.Popen([sys.executable, "relay/account_store.py", "--database",
                str(database_path), "--port", "48046"], cwd=root,
                stdout=log, stderr=log, creationflags=creationflags))
            relay_path = "." if simulation else "relay"
            relay_script = "res://tests/support/matchmaking_simulation_relay.gd" if simulation else "res://server.gd"
            services.append(subprocess.Popen([str(godot), "--headless", "--path", relay_path,
                "--log-file", str(scratch / f"{log_prefix}relay.log"), "--script", relay_script, "--",
                "--bind", "127.0.0.1", "--port", "48045", "--transport", "websocket",
                "--account-port", "48046", *(["--test-matchmaking-simulation"] if simulation else [])], cwd=root, stdout=log, stderr=log, creationflags=creationflags))
            deadline = time.monotonic() + 10
            while not (ready(48045) and ready(48046)):
                if time.monotonic() > deadline or any(p.poll() is not None for p in services):
                    raise RuntimeError(f"Local test services failed to start; see {scratch / (log_prefix + 'services.log')}")
                time.sleep(0.1)
            test_args = ["--script", "res://tests/test_cloud_rooms.gd", "--", "--server", "ws://127.0.0.1:48045"] if "--rooms-only" in sys.argv else ["--script", "res://tests/test_cloud_matchmaking.gd"]
            if simulation:test_args = ["--script", "res://tests/test_matchmaking_simulation.gd", "--", "--manifest", str(manifest)]
            result = subprocess.run([str(godot), "--headless", "--path", ".", "--log-file",
                str(scratch / f"{log_prefix}test.log"), *test_args],
                cwd=root, creationflags=creationflags, timeout=180, capture_output=True, encoding="utf-8", errors="replace")
            print(result.stdout, end="", flush=True)
            print(result.stderr, end="", flush=True)
            if result.returncode:
                with sqlite3.connect(Path(temp) / "players.sqlite3") as conn:
                    print("Match storage:", conn.execute("SELECT status,winner,elo_a,elo_b FROM rating_matches").fetchall(), flush=True)
                conn.close()
                raise SystemExit(result.returncode)
    finally:
        for service in reversed(services):
            service.terminate()
        for service in services:
            service.wait(timeout=10)
