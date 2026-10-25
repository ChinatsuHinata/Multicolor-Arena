"""Run the competition UI against isolated loopback services and a temporary DB."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

root = Path(__file__).resolve().parents[1]
godot = root / ".godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe"
scratch = root / "work/tournament-tests"
scratch.mkdir(parents=True, exist_ok=True)
flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
sys.path.insert(0, str(root / "relay"))
import account_store as accounts


def ready(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
            return True
    except OSError:
        return False


if ready(48065) or ready(48066):
    raise SystemExit("Test ports 48065 and 48066 must be unused.")

with tempfile.TemporaryDirectory(prefix="TEST_ONLY_", dir=scratch) as directory:
    services = []
    try:
        fixture = Path(directory)
        database_path = fixture / "players.sqlite3"
        conn = accounts.database(database_path)
        logins = {}
        for index, name in enumerate(("bigcake", "first_player", "second_player", "third_player", "fourth_player")):
            credentials = {"username": name, "password": "TEST_ONLY_password123!", "device": str(index) * 32}
            assert accounts.handle(conn, {"action": "register", **credentials})["ok"]
            login = accounts.handle(conn, {"action": "login", **credentials})
            assert accounts.handle(conn, {"action":"nickname", "token":login["token"], "nickname":name})["ok"]
            login["nickname"] = name
            logins[name] = {"token": login["token"], "nickname": login["nickname"],
                            "player_id": accounts.verify(conn, login["token"])["player_id"]}
        limitless_tid = 0
        if "--limitless-only" in sys.argv:
            import tournament_store
            created = tournament_store.handle(conn, {"action":"create", "title":"Limitless 审核通信测试", "start_at":int(time.time())+3600},
                {"ok":True,"username":"bigcake","player_id":logins["bigcake"]["player_id"]})
            limitless_tid = created["tournament"]["id"]
            snapshot = {"title":"测试来源", "started":True, "finished":False, "phases":[], "pairings":[],
                "standings":[{"player":"doctorblack","name":"黑心 博士","placing":1,"wins":1,"losses":0,"ties":0,"drop":False}]}
            with conn:
                conn.execute("UPDATE tournaments SET phase='locked' WHERE id=?", (limitless_tid,))
                conn.execute("INSERT INTO tournament_limitless(tournament_id,external_id,generation,snapshot_json,synced_at) VALUES(?,'6aba47b9783097f8dcb72660','test',?,?)", (limitless_tid,json.dumps(snapshot),int(time.time())))
        conn.close()
        config = fixture / "fixture.json"
        config.write_text(json.dumps({"folder": str(fixture), "logins": logins, "limitless_tournament":limitless_tid}), encoding="utf-8")
        with (scratch / "services.log").open("w", encoding="utf-8") as log:
            services.append(subprocess.Popen([sys.executable, "relay/account_store.py", "--database", str(database_path),
                "--port", "48066"], cwd=root, stdout=log, stderr=log, creationflags=flags))
            services.append(subprocess.Popen([str(godot), "--headless", "--path", "relay", "--log-file",
                str(scratch / "relay.log"), "--script", "res://server.gd", "--", "--bind", "127.0.0.1",
                "--port", "48065", "--transport", "websocket", "--account-port", "48066"],
                cwd=root, stdout=log, stderr=log, creationflags=flags))
            deadline = time.monotonic() + 15
            while not (ready(48065) and ready(48066)):
                if time.monotonic() > deadline or any(p.poll() is not None for p in services):
                    raise RuntimeError(f"Local test services failed to start; see {scratch / 'services.log'}")
                time.sleep(0.1)
            display = ["--rendering-method", "gl_compatibility"] if "--render" in sys.argv else ["--headless"]
            scripts = ("test_tournament_unread.gd", "test_tournaments.gd", "test_tournament_rounds.gd", "test_tournament_game_formats.gd")
            if "--unread-only" in sys.argv:
                scripts = ("test_tournament_unread.gd",)
            elif "--formats-only" in sys.argv:
                scripts = ("test_tournament_game_formats.gd",)
            elif "--rounds-only" in sys.argv:
                scripts = ("test_tournament_rounds.gd",)
            elif "--community-only" in sys.argv:
                scripts = ("test_community_online.gd",)
            elif "--limitless-only" in sys.argv:
                scripts = ("test_limitless_online.gd",)
            for script in scripts:
                result = subprocess.run([str(godot), *display, "--path", ".", "--log-file", str(scratch / (script + ".log")),
                    "--script", "res://tests/" + script, "--", "--fixture", str(config), *(["--forfeit-only"] if "--forfeit-only" in sys.argv else [])],
                    cwd=root, creationflags=flags, timeout=300 if script == "test_tournament_game_formats.gd" else 150, capture_output=True, encoding="utf-8", errors="replace")
                print(result.stdout, end="", flush=True)
                print(result.stderr, end="", flush=True)
                if result.returncode:
                    raise SystemExit(result.returncode)
    finally:
        for service in reversed(services):
            service.terminate()
        for service in services:
            service.wait(timeout=10)
