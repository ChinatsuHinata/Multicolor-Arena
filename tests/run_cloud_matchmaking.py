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
client_pack = None
if "--client-pack" in sys.argv:
    client_pack = Path(sys.argv[sys.argv.index("--client-pack") + 1]).resolve()
    if not client_pack.is_file():
        raise SystemExit("Client package must exist.")

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
        recovery = "--recovery-only" in sys.argv
        attribution = "--attribution-only" in sys.argv
        restart = "--restart-only" in sys.argv
        casual = "--casual-only" in sys.argv
        exploration = "--exploration-only" in sys.argv
        if simulation and recovery:
            raise SystemExit("Choose either --simulation-only or --recovery-only.")
        log_prefix = "response-timeout-" if "--response-timeout-only" in sys.argv else "exploration-random-" if exploration and "--random" in sys.argv else "exploration-" if exploration else "casual-" if casual else "restart-" if restart else "simulation-" if simulation else "recovery-" if recovery else "rooms-" if "--rooms-only" in sys.argv else ""
        database_path = Path(temp) / "players.sqlite3"
        if simulation:
            sys.path.insert(0, str(root / "relay"))
            import account_store
            conn = account_store.database(database_path)
            players = []
            for index, (step, rating) in enumerate(((0, 1000), (1, 1000), (0, 2500), (1, 1600), (5, 1400), (10, 1400), (0, 1000))):
                payload = {"username": f"TEST_ONLY_sim_{index}", "password": "password123!", "device": "d" * 32}
                assert account_store.handle(conn, {"action": "register", **payload})["ok"]
                conn.execute("UPDATE players SET rank_step=?,elo=? WHERE username=?", (step, rating, payload["username"]))
                conn.commit()
                login = account_store.handle(conn, {"action": "login", **payload})
                assert login["ok"]
                players.append({"token": login["token"], "nickname": login["nickname"], "rank": login["rank"]})
            conn.close()
            import json
            manifest = Path(temp) / "clients.json"
            manifest.write_text(json.dumps({"endpoint": "ws://127.0.0.1:48045", "players": players}), encoding="utf-8")
        elif recovery or attribution:
            sys.path.insert(0, str(root / "relay"))
            import account_store
            import json
            conn = account_store.database(database_path)
            players = []
            for index in range(2):
                payload = {"username": f"TEST_ONLY_recovery_{index}", "password": "password123!", "device": "d" * 32}
                assert account_store.handle(conn, {"action": "register", **payload})["ok"]
                login = account_store.handle(conn, {"action": "login", **payload})
                assert login["ok"]
                players.append({"token": login["token"]})
            conn.close()
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
            if recovery:test_args = ["--script", "res://tests/test_match_recovery_network.gd", "--", str(manifest)]
            if attribution:test_args = ["--script", "res://tests/test_connection_attribution_network.gd", "--", str(manifest)]
            if restart:test_args = ["--script", "res://tests/test_ranked_restart.gd"]
            if casual:test_args = ["--script", "res://tests/test_casual_matchmaking.gd"]
            if exploration:test_args = ["--script", "res://tests/test_exploration_matchmaking.gd", *(["--", "--random"] if "--random" in sys.argv else [])]
            if "--response-timeout-only" in sys.argv:test_args = ["--script", "res://tests/test_cloud_response_timeout.gd"]
            client_env = os.environ.copy()
            client_env["MULTICOLOR_TEST_STORAGE"] = str(Path(temp) / "client-state")
            if client_pack:
                if test_args != ["--script", "res://tests/test_cloud_matchmaking.gd"]:
                    raise SystemExit("--client-pack runs the full matchmaking suite.")
                test_args = ["--main-pack", str(client_pack), "--script", str(root / "tests/test_cloud_matchmaking.gd")]
            result = subprocess.run([str(godot), "--headless", "--path", ".", "--log-file",
                str(scratch / f"{log_prefix}test.log"), *test_args],
                cwd=root, env=client_env, creationflags=creationflags, timeout=240 if attribution else 180, capture_output=True, encoding="utf-8", errors="replace")
            print(result.stdout, end="", flush=True)
            print(result.stderr, end="", flush=True)
            if result.returncode:
                with sqlite3.connect(Path(temp) / "players.sqlite3") as conn:
                    print("Match storage:", conn.execute("SELECT status,winner,elo_a,elo_b FROM rating_matches").fetchall(), flush=True)
                conn.close()
                raise SystemExit(result.returncode)
            if attribution:
                import json
                with sqlite3.connect(database_path) as conn:
                    rows = conn.execute("SELECT m.winner,m.player_a,m.player_b,r.detail FROM rating_matches m JOIN match_resolutions r USING(match_id) WHERE m.status='settled'").fetchall()
                    assert len(rows) == 2, rows
                    for winner, first, second, detail in rows:
                        evidence = json.loads(detail)
                        assert evidence["reason"] == "player_link_timeout", evidence
                        assert evidence["evidence"][0]["player_id"] == (first, second)[1-winner], evidence
                    print("PASS: both opposite-side disconnect decisions match durable player IDs and winners")
                conn.close()
    finally:
        for service in reversed(services):
            service.terminate()
        for service in services:
            service.wait(timeout=10)
