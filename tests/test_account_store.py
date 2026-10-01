"""Current cloud account session and nickname behavior."""

import importlib.util
import hashlib
import sqlite3
import tempfile
import time
import sys
from pathlib import Path


source = Path(__file__).resolve().parents[1] / "relay" / "account_store.py"
sys.path.insert(0, str(source.parent))
spec = importlib.util.spec_from_file_location("account_store", source)
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)

with tempfile.TemporaryDirectory() as directory:
    db_path = Path(directory) / "players.sqlite3"
    legacy = sqlite3.connect(db_path)
    legacy.execute("""CREATE TABLE players (
        id INTEGER PRIMARY KEY, username TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_salt BLOB NOT NULL, password_hash BLOB NOT NULL,
        created_at INTEGER NOT NULL, last_login_at INTEGER)""")
    legacy.execute("""CREATE TABLE sessions (
        player_id INTEGER PRIMARY KEY, token_hash BLOB NOT NULL,
        device TEXT NOT NULL, issued_at INTEGER NOT NULL)""")
    old_token = "e" * 64
    legacy.execute("INSERT INTO players VALUES(?,?,?,?,?,?)",
                   (1, "legacy_player", b"0" * 16, b"0" * 32, int(time.time()), None))
    legacy.execute("INSERT INTO sessions VALUES(?,?,?,?)",
                   (1, hashlib.sha256(old_token.encode("ascii")).digest(), "f" * 32, int(time.time())))
    legacy.commit()
    legacy.close()
    conn = store.database(db_path)
    columns = {row[1] for row in conn.execute("PRAGMA table_info(sessions)")}
    assert {"platform", "remember_hash", "remember_issued_at"} <= columns
    assert store.handle(conn, {"action": "verify", "token": old_token})["platform"] == "pc"
    user = "cloud_test_player"
    first = "a" * 32
    second = "b" * 32
    third = "c" * 32
    fourth = "d" * 32
    assert store.handle(conn, {"action": "register", "username": user,
                               "password": "password123!", "device": first})["ok"]
    login_a = store.handle(conn, {"action": "login", "username": user,
                                  "password": "password123!", "device": first})
    assert login_a["ok"] and store.handle(conn, {"action": "verify", "token": login_a["token"]})["device"] == first
    assert store.handle(conn, {"action": "verify", "token": login_a["token"]})["platform"] == "pc"
    assert len(login_a["remember_token"]) == 64
    assert not store.handle(conn, {"action": "resume", "remember_token": login_a["remember_token"],
                                   "device": second})["ok"]
    resumed = store.handle(conn, {"action": "resume", "remember_token": login_a["remember_token"],
                                  "device": first})
    assert resumed["ok"] and resumed["username"] == user
    assert not store.handle(conn, {"action": "verify", "token": login_a["token"]})["ok"]
    assert not store.handle(conn, {"action": "resume", "remember_token": login_a["remember_token"],
                                   "device": first})["ok"]
    assert len(resumed["remember_token"]) == 64 and resumed["remember_token"] != login_a["remember_token"]
    renamed = store.handle(conn, {"action": "nickname", "token": resumed["token"],
                                  "nickname": "云端玩家"})
    assert renamed["ok"] and renamed["nickname"] == "云端玩家"
    android = store.handle(conn, {"action": "login", "username": user,
                                  "password": "password123!", "device": second, "platform": "android"})
    assert android["ok"] and android["nickname"] == "云端玩家"
    assert store.handle(conn, {"action": "verify", "token": android["token"]})["platform"] == "android"
    assert store.handle(conn, {"action": "verify", "token": resumed["token"]})["ok"]
    assert not store.handle(conn, {"action": "resume", "remember_token": android["remember_token"],
                                   "device": second, "platform": "pc"})["ok"]
    android_resumed = store.handle(conn, {"action": "resume", "remember_token": android["remember_token"],
                                         "device": second, "platform": "android"})
    assert android_resumed["ok"] and android_resumed["platform"] == "android"
    assert store.handle(conn, {"action": "verify", "token": resumed["token"]})["ok"]
    assert store.handle(conn, {"action": "resume", "remember_token": resumed["remember_token"],
                               "device": second})["ok"] is False
    android_new = store.handle(conn, {"action": "login", "username": user,
                                      "password": "password123!", "device": fourth, "platform": "android"})
    assert android_new["ok"]
    assert not store.handle(conn, {"action": "verify", "token": android_resumed["token"]})["ok"]
    assert store.handle(conn, {"action": "verify", "token": resumed["token"]})["ok"]
    pc_new = store.handle(conn, {"action": "login", "username": user,
                                 "password": "password123!", "device": third, "platform": "pc"})
    assert pc_new["ok"]
    assert not store.handle(conn, {"action": "verify", "token": resumed["token"]})["ok"]
    assert store.handle(conn, {"action": "verify", "token": android_new["token"]})["ok"]
    assert store.handle(conn, {"action": "logout", "token": android_new["token"]})["ok"]
    assert not store.handle(conn, {"action": "verify", "token": android_new["token"]})["ok"]
    assert store.handle(conn, {"action": "verify", "token": pc_new["token"]})["ok"]
    assert not store.handle(conn, {"action": "login", "username": user,
                                   "password": "password123!", "device": second,
                                   "platform": "tablet"})["ok"]
    expired = store.handle(conn, {"action": "login", "username": user,
                                  "password": "password123!", "device": first})
    conn.execute("UPDATE sessions SET issued_at=issued_at-?", (store.SESSION_LIFETIME + 1,))
    conn.commit()
    assert store.handle(conn, {"action": "logout", "token": expired["token"],
                               "remember_token": expired["remember_token"], "device": first})["ok"]
    assert not store.handle(conn, {"action": "resume", "remember_token": expired["remember_token"],
                                   "device": first})["ok"]
    expired = store.handle(conn, {"action": "login", "username": user,
                                  "password": "password123!", "device": first})
    conn.execute("UPDATE sessions SET remember_issued_at=remember_issued_at-?", (store.REMEMBER_LIFETIME + 1,))
    conn.commit()
    assert not store.handle(conn, {"action": "resume", "remember_token": expired["remember_token"],
                                   "device": first})["ok"]
    conn.close()

print("PASS: one PC and one Android session, slot replacement, migration, rotation, expiry, nickname, and logout")
