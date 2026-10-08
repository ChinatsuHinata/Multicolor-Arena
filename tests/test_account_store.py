"""Current cloud account session and nickname behavior."""

import importlib.util
import base64
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
    assert store.handle(conn, {"action": "verify", "token": old_token})["elo"] == 1000
    # A second migration preserves already stored values and existing sessions.
    conn.execute("UPDATE players SET elo=1123 WHERE id=1")
    conn.commit()
    conn.close()
    conn = store.database(db_path)
    assert store.handle(conn, {"action": "verify", "token": old_token})["elo"] == 1123
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
    assert login_a["elo"] == 1000
    assert store.handle(conn, {"action": "verify", "token": login_a["token"], "username": "legacy_player"})["elo"] == 1000
    assert not store.handle(conn, {"action": "elo", "token": login_a["token"], "elo": 2000})["ok"]
    assert store.handle(conn, {"action": "verify", "token": login_a["token"]})["platform"] == "pc"
    assert len(login_a["remember_token"]) == 64
    assert not store.handle(conn, {"action": "resume", "remember_token": login_a["remember_token"],
                                   "device": second})["ok"]
    resumed = store.handle(conn, {"action": "resume", "remember_token": login_a["remember_token"],
                                  "device": first})
    assert resumed["ok"] and resumed["username"] == user
    assert resumed["elo"] == 1000
    assert not store.handle(conn, {"action": "verify", "token": login_a["token"]})["ok"]
    assert not store.handle(conn, {"action": "resume", "remember_token": login_a["remember_token"],
                                   "device": first})["ok"]
    assert len(resumed["remember_token"]) == 64 and resumed["remember_token"] != login_a["remember_token"]
    renamed = store.handle(conn, {"action": "nickname", "token": resumed["token"],
                                  "nickname": "云端玩家"})
    assert renamed["ok"] and renamed["nickname"] == "云端玩家"
    assert renamed["elo"] == 1000
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

with tempfile.TemporaryDirectory() as directory:
    conn = store.database(Path(directory) / "players.sqlite3")
    payload = {"username": "password_player", "password": "old-password!", "device": "a" * 32}
    assert store.handle(conn, {"action": "register", **payload})["ok"]
    pc = store.handle(conn, {"action": "login", **payload})
    android = store.handle(conn, {"action": "login", **payload, "platform": "android"})
    conn.execute("UPDATE players SET nickname='原昵称',elo=1234 WHERE username=?", (payload["username"],))
    conn.commit()
    original = conn.execute("SELECT password_salt,password_hash FROM players").fetchone()

    def unchanged():
        assert conn.execute("SELECT password_salt,password_hash FROM players").fetchone() == original
        assert store.verify(conn, pc["token"])["ok"] and store.verify(conn, android["token"])["ok"]

    def authorize(password="old-password!"):
        secret = "abcdefghijklmnopqrstuv"
        answer = store.handle(conn, {"action": "pwa", "username": payload["username"].upper(),
                                      "password": password, "nickname": secret})
        if answer["ok"]:
            public_nonce = answer["password_ticket"]
            assert public_nonce not in store.password_changes
            assert not stage("pw_set", public_nonce)["ok"]
            answer["password_ticket"] = hashlib.sha256((secret + ":" + public_nonce).encode()).hexdigest()[:32]
        return answer

    def stage(action, ticket, password="new-password!"):
        return store.handle(conn, {"action": action, "token": ticket, "password": password})

    assert not authorize("wrong-password!")["ok"]
    unchanged()
    assert not stage("pw_set", "f" * 32)["ok"]
    for password in (None, "short", "x" * 65, "中" * 33):
        assert not authorize(password)["ok"]
    ticket = authorize()["password_ticket"]
    assert not stage("pw_confirm", ticket)["ok"]
    assert not stage("pw_set", ticket)["ok"]
    unchanged()
    ticket = authorize()["password_ticket"]
    assert not stage("pw_set", ticket, "old-password!")["ok"]
    unchanged()
    ticket = authorize()["password_ticket"]
    assert stage("pw_set", ticket)["ok"]
    unchanged()  # Merely supplying a new password must never update it.
    assert not stage("pw_confirm", ticket, "different-password!")["ok"]
    assert not stage("pw_confirm", ticket)["ok"]
    unchanged()
    ticket = authorize()["password_ticket"]
    store.password_changes[ticket]["issued_at"] -= store.PASSWORD_CHANGE_LIFETIME
    assert not stage("pw_set", ticket)["ok"]
    unchanged()
    ticket = authorize()["password_ticket"]
    replacement_ticket = authorize()["password_ticket"]
    assert not stage("pw_set", ticket)["ok"]
    assert stage("pw_set", replacement_ticket)["ok"]
    # An intervening administrative reset invalidates a previously authorized change.
    conn.execute("UPDATE players SET password_hash=?", (b"changed hash",))
    conn.commit()
    assert not stage("pw_confirm", replacement_ticket)["ok"]
    conn.execute("UPDATE players SET password_hash=?", (original[1],))
    conn.commit()
    unchanged()
    for _ in range(store.MAX_FAILURES):
        assert not authorize("wrong-password!")["ok"]
    assert "尝试次数过多" in authorize()["message"]
    unchanged()
    store.failures.clear()
    ticket = authorize()["password_ticket"]
    new_password = '\\"' * 32
    assert stage("pw_set", ticket, new_password)["ok"]
    assert stage("pw_confirm", ticket, new_password)["ok"]
    assert not stage("pw_confirm", ticket, new_password)["ok"]
    changed = conn.execute("SELECT password_salt,password_hash FROM players").fetchone()
    assert changed[0] != original[0] and changed[1] != original[1]
    assert changed[1] == hashlib.pbkdf2_hmac("sha256", new_password.encode(), changed[0], store.ITERATIONS)
    for session, platform in ((pc, "pc"), (android, "android")):
        assert not store.verify(conn, session["token"])["ok"]
        assert not store.handle(conn, {"action": "resume", "remember_token": session["remember_token"],
                                       "device": payload["device"], "platform": platform})["ok"]
    assert not store.handle(conn, {"action": "login", **payload})["ok"]
    login = store.handle(conn, {"action": "login", **payload, "password": new_password})
    assert login["ok"] and login["nickname"] == "原昵称" and login["elo"] == 1234
    encoded_password = {"b": base64.b64encode(new_password.encode()).decode()}
    assert store.handle(conn, {"action": "login", **payload, "password": encoded_password})["ok"]
    assert store.handle(conn, {"action": "register", **payload, "username": "encoded_password_player", "password": encoded_password})["ok"]
    for invalid in ({"b": "!"}, {"b": "A" * 132}, {"b": 1}, {"b": "", "extra": True}, {"b": "/w=="}):
        assert not store.handle(conn, {"action": "login", **payload, "password": invalid})["ok"]
    conn.close()

print("PASS: account sessions, Elo, nickname, old-password validation, confirmation, expiry, replay, rate limit, atomic change, and revocation on both platforms")
