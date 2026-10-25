"""Exercise the task UI against a real relay and account service on loopback only."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
from unittest import mock

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "relay"))
import account_store as accounts
import task_store as tasks

godot = root / ".godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe"
scratch = root / "work/task-tests"
scratch.mkdir(parents=True, exist_ok=True)
flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0


def ready(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
            return True
    except OSError:
        return False


if ready(48071) or ready(48072):
    raise SystemExit("Task test ports 48071 and 48072 must be unused.")

with tempfile.TemporaryDirectory(prefix="TEST_ONLY_UI_", dir=scratch) as directory:
    services = []
    fixture = Path(directory)
    database_path = fixture / "players.sqlite3"
    conn = accounts.database(database_path)
    logins = {}
    for index, name in enumerate(("TEST_ONLY_tasks", "TEST_ONLY_opponent", "TEST_ONLY_cards", "TEST_ONLY_coin")):
        credentials = {"username": name, "password": "TEST_ONLY_password123!", "device": str(index) * 32}
        assert accounts.handle(conn, {"action": "register", **credentials})["ok"]
        login = accounts.handle(conn, {"action": "login", **credentials})
        assert login["ok"]
        logins[name] = login["token"]
    all_players = [r[0] for r in conn.execute("SELECT id FROM players ORDER BY id")]
    players = all_players[:2]
    # Stable scenario, using the production catalogue and match settlement path.
    with conn:
        day = tasks.today()
        tasks.ensure_daily(conn, players[0], day)
        for slot, group in enumerate(("player_damage", "units_destroyed", "healthy_win")):
            definition = tasks.choose_definition("advanced" if slot == 2 else "basic",
                [entry["group"] for entry in tasks.CATALOGUE if entry["group"] != group])
            tasks.put_assignment(conn, players[0], day, slot, definition)
        tasks.ensure_daily(conn, all_players[2], day)
        for slot, group in enumerate(("spell_counters", "player_damage", "signature_spell")):
            with mock.patch.object(tasks.secrets, "choice", side_effect=lambda entries: next((entry for entry in entries if entry.get("key") == "121"), entries[0])):
                definition = tasks.choose_definition("advanced" if slot == 2 else "basic",
                    [entry["group"] for entry in tasks.CATALOGUE if entry["group"] != group])
            tasks.put_assignment(conn, all_players[2], day, slot, definition)
        tasks.ensure_daily(conn, all_players[3], day)
        for slot, group in enumerate(("player_damage", "units_destroyed", "special_win")):
            with mock.patch.object(tasks.secrets, "choice", side_effect=lambda entries: next((entry for entry in entries if entry.get("key") == "coin"), entries[0])):
                definition = tasks.choose_definition("advanced" if slot == 2 else "basic",
                    [entry["group"] for entry in tasks.CATALOGUE if entry["group"] != group])
            tasks.put_assignment(conn, all_players[3], day, slot, definition)
    base = {"match_id": f"{100:032x}"}
    evidence = {"version": 1, "players": [{"player_damage": 40, "units_destroyed": 3, "final_life": 31}, {}]}
    for action in ("create", "start", "settle"):
        assert accounts.handle_match(conn, {**base, "action": action, "players": players, "winner": 0, "evidence": evidence})["ok"]
    conn.close()
    config = fixture / "fixture.json"
    config.write_text(json.dumps({"folder": str(fixture), "logins": logins}), encoding="utf-8")
    try:
        with (scratch / "services.log").open("w", encoding="utf-8") as log:
            services.append(subprocess.Popen([sys.executable, "relay/account_store.py", "--database", str(database_path), "--port", "48072"], cwd=root, stdout=log, stderr=log, creationflags=flags))
            services.append(subprocess.Popen([str(godot), "--headless", "--path", "relay", "--log-file", str(scratch / "relay.log"), "--script", "res://server.gd", "--", "--bind", "127.0.0.1", "--port", "48071", "--transport", "websocket", "--account-port", "48072"], cwd=root, stdout=log, stderr=log, creationflags=flags))
            deadline = time.monotonic() + 15
            while not (ready(48071) and ready(48072)):
                if time.monotonic() > deadline or any(p.poll() is not None for p in services):
                    raise RuntimeError(f"Local task services failed to start; see {scratch / 'services.log'}")
                time.sleep(0.1)
            display = ["--rendering-method", "gl_compatibility"] if "--render" in sys.argv else ["--headless"]
            result = subprocess.run([str(godot), *display, "--path", ".", "--log-file", str(scratch / "ui.log"), "--script", "res://tests/test_tasks_ui.gd", "--", "--fixture", str(config)], cwd=root, creationflags=flags, timeout=150, capture_output=True, encoding="utf-8", errors="replace")
            print(result.stdout, end="", flush=True)
            print(result.stderr, end="", flush=True)
            if result.returncode or "SCRIPT ERROR" in result.stderr:
                raise SystemExit(result.returncode or 1)
        # Even after memory tampering in the UI, the actual database is unchanged.
        conn = accounts.database(database_path)
        assert conn.execute("SELECT coins FROM task_wallets WHERE player_id=?", (players[0],)).fetchone()[0] == 1
        assert conn.execute("SELECT COUNT(*) FROM task_rewards WHERE player_id=? AND category='daily'", (players[0],)).fetchone()[0] == 1
        conn.close()
    finally:
        for service in reversed(services):
            service.terminate()
        for service in services:
            service.wait(timeout=10)
