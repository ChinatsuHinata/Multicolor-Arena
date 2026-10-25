"""Verify purchase-to-match behavior using only loopback and a temporary database."""
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "relay"))
import account_store as accounts
import shop_store as shop

GODOT = ROOT / ".godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe"
scratch = ROOT / "work/shop-tests"
scratch.mkdir(parents=True, exist_ok=True)
flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0


def ready(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=1):return True
    except OSError:return False


if ready(48073) or ready(48074):raise SystemExit("Local shop test ports are in use")
with tempfile.TemporaryDirectory(prefix="TEST_ONLY_shop_", dir=scratch) as directory:
    folder = Path(directory)
    database = folder / "players.sqlite3"
    conn = accounts.database(database)
    token = "b" * 64
    with conn:
        conn.execute("INSERT INTO players(id,username,password_salt,password_hash,created_at) VALUES(1,'TEST_ONLY_shop',?,?,0)", (b"salt",b"hash"))
        conn.execute("INSERT INTO sessions(player_id,platform,token_hash,device,issued_at) VALUES(1,'pc',?,?,?)", (hashlib.sha256(token.encode()).digest(),"d"*32,int(time.time())))
        conn.execute("INSERT INTO task_wallets(player_id,coins) VALUES(1,?)", (shop.price_for("emotes_reimu"),))
    conn.close()
    fixture = folder / "fixture.json"
    fixture.write_text(json.dumps({"folder":str(folder),"token":token,"price":shop.price_for("emotes_reimu")}), encoding="utf-8")
    services = []
    try:
        with (scratch / "services.log").open("w", encoding="utf-8") as log:
            services.append(subprocess.Popen([sys.executable,"relay/account_store.py","--database",str(database),"--port","48074"],cwd=ROOT,stdout=log,stderr=log,creationflags=flags))
            services.append(subprocess.Popen([str(GODOT),"--headless","--path","relay","--log-file",str(scratch/"relay.log"),"--script","res://server.gd","--","--bind","127.0.0.1","--port","48073","--transport","websocket","--account-port","48074"],cwd=ROOT,stdout=log,stderr=log,creationflags=flags))
            deadline=time.monotonic()+45
            while not (ready(48073) and ready(48074)):
                if time.monotonic()>deadline or any(p.poll() is not None for p in services):raise RuntimeError("Loopback services failed; see services.log")
                time.sleep(0.1)
            result=subprocess.run([str(GODOT),"--headless","--path",".","--log-file",str(scratch/"network.log"),"--script","res://tests/test_shop_network.gd","--","--fixture",str(fixture)],cwd=ROOT,creationflags=flags,timeout=180,capture_output=True,encoding="utf-8",errors="replace")
            print(result.stdout);print(result.stderr)
            if result.returncode or "SCRIPT ERROR" in result.stderr:raise SystemExit(result.returncode or 1)
        conn=accounts.database(database)
        assert conn.execute("SELECT coins FROM task_wallets WHERE player_id=1").fetchone()[0]==0
        assert conn.execute("SELECT product_id,price FROM shop_purchases WHERE player_id=1 ORDER BY product_id").fetchall()==[
            ("emotes_reimu",shop.price_for("emotes_reimu")), ("entrance_reimu_yinyang_gather",0), ("spell_reimu_dream_orbs",0)]
        conn.close()
    finally:
        for process in reversed(services):process.terminate()
        for process in services:process.wait(timeout=10)
