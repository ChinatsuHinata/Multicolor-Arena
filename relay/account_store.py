#!/usr/bin/env python3
"""Loopback-only SQLite account store for the Godot relay."""

import argparse
import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import deck_plaza_store

USERNAME = re.compile(r"[A-Za-z0-9_]{3,24}\Z", re.ASCII)
DEVICE = re.compile(r"[a-f0-9]{32}\Z", re.ASCII)
PLATFORMS = ("pc", "android")
ITERATIONS = 310_000
FAIL_WINDOW = 900
MAX_FAILURES = 5
SESSION_LIFETIME = 24 * 60 * 60
REMEMBER_LIFETIME = 30 * 24 * 60 * 60
failures = {}


def database(path):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)
    conn = sqlite3.connect(path)
    if os.name != "nt":
        os.chmod(path, 0o600)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("""CREATE TABLE IF NOT EXISTS players (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_salt BLOB NOT NULL,
        password_hash BLOB NOT NULL,
        created_at INTEGER NOT NULL,
        last_login_at INTEGER
    )""")
    columns = {row[1] for row in conn.execute("PRAGMA table_info(players)")}
    if "nickname" not in columns:
        conn.execute("ALTER TABLE players ADD COLUMN nickname TEXT NOT NULL DEFAULT ''")
    conn.execute("""CREATE TABLE IF NOT EXISTS sessions (
        player_id INTEGER NOT NULL,
        platform TEXT NOT NULL,
        token_hash BLOB NOT NULL,
        device TEXT NOT NULL,
        issued_at INTEGER NOT NULL,
        remember_hash BLOB,
        remember_issued_at INTEGER,
        PRIMARY KEY(player_id, platform),
        FOREIGN KEY(player_id) REFERENCES players(id)
    )""")
    session_columns = {row[1] for row in conn.execute("PRAGMA table_info(sessions)")}
    if "remember_hash" not in session_columns:
        conn.execute("ALTER TABLE sessions ADD COLUMN remember_hash BLOB")
    if "remember_issued_at" not in session_columns:
        conn.execute("ALTER TABLE sessions ADD COLUMN remember_issued_at INTEGER")
    if "platform" not in session_columns:
        # Old installations held one session per account. Keep it in the PC slot;
        # older clients without a platform field also continue to use that slot.
        with conn:
            conn.execute("""CREATE TABLE sessions_by_platform (
                player_id INTEGER NOT NULL, platform TEXT NOT NULL,
                token_hash BLOB NOT NULL, device TEXT NOT NULL,
                issued_at INTEGER NOT NULL, remember_hash BLOB,
                remember_issued_at INTEGER,
                PRIMARY KEY(player_id, platform),
                FOREIGN KEY(player_id) REFERENCES players(id))""")
            conn.execute("""INSERT INTO sessions_by_platform
                SELECT player_id,'pc',token_hash,device,issued_at,remember_hash,remember_issued_at
                FROM sessions""")
            conn.execute("DROP TABLE sessions")
            conn.execute("ALTER TABLE sessions_by_platform RENAME TO sessions")
    conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS sessions_token_hash ON sessions(token_hash)")
    conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS sessions_remember_hash ON sessions(remember_hash)")
    deck_plaza_store.initialize(conn)
    conn.commit()
    return conn


def response(ok, message, username="", nickname="", token="", remember_token="", platform=""):
    return {"ok": ok, "message": message, "username": username,
            "nickname": nickname, "token": token, "remember_token": remember_token,
            "platform": platform}


def verify(conn, token):
    if not isinstance(token, str) or not re.fullmatch(r"[a-f0-9]{64}", token, re.ASCII):
        return response(False, "登录凭据无效")
    digest = hashlib.sha256(token.encode("ascii")).digest()
    row = conn.execute("""SELECT p.id,p.username,p.nickname,s.token_hash,s.device,s.issued_at,s.platform
        FROM sessions s JOIN players p ON p.id=s.player_id WHERE s.token_hash=?""", (digest,)).fetchone()
    if row and hmac.compare_digest(digest, row[3]) and time.time() - row[5] < SESSION_LIFETIME:
        player_id, username, nickname, _, device, _, platform = row
        return {"ok": True, "username": username, "nickname": nickname or username,
                "device": device, "platform": platform, "player_id": player_id}
    return response(False, "登录已失效，请重新登录")


def remembered_session(conn, token, device):
    if not isinstance(token, str) or not re.fullmatch(r"[a-f0-9]{64}", token, re.ASCII):
        return None
    if not isinstance(device, str) or not DEVICE.fullmatch(device):
        return None
    digest = hashlib.sha256(token.encode("ascii")).digest()
    row = conn.execute("""SELECT p.id,p.username,p.nickname,s.remember_hash,s.remember_issued_at,s.platform
        FROM sessions s JOIN players p ON p.id=s.player_id
        WHERE s.remember_hash=? AND s.device=?""", (digest, device)).fetchone()
    if row and row[3] is not None and hmac.compare_digest(digest, row[3]) and row[4] is not None and time.time() - row[4] < REMEMBER_LIFETIME:
        return row
    return None


def handle(conn, data):
    if not isinstance(data, dict):
        return response(False, "请求格式无效")
    action = data.get("action")
    if action == "resume":
        row = remembered_session(conn, data.get("remember_token"), data.get("device"))
        if row is None or row[5] != data.get("platform", "pc"):
            return response(False, "自动登录已失效，请重新登录")
        now = int(time.time())
        token = secrets.token_hex(32)
        remember_token = secrets.token_hex(32)
        with conn:
            conn.execute("""UPDATE sessions SET token_hash=?,issued_at=?,remember_hash=?,remember_issued_at=?
                WHERE player_id=? AND platform=?""", (hashlib.sha256(token.encode("ascii")).digest(), now,
                    hashlib.sha256(remember_token.encode("ascii")).digest(), now, row[0], row[5]))
        return response(True, "已自动登录", row[1], row[2] or row[1], token, remember_token, row[5])
    if action in ("verify", "nickname", "logout"):
        account = verify(conn, data.get("token"))
        if action == "logout" and not account["ok"]:
            row = remembered_session(conn, data.get("remember_token"), data.get("device"))
            if row is not None:
                with conn:
                    conn.execute("DELETE FROM sessions WHERE player_id=? AND platform=?", (row[0], row[5]))
                return response(True, "已退出账号")
        if not account["ok"]:
            return account
        if action == "verify":
            return account
        if action == "logout":
            with conn:
                conn.execute("DELETE FROM sessions WHERE player_id=? AND platform=?",
                             (account["player_id"], account["platform"]))
            return response(True, "已退出账号")
        nickname = data.get("nickname")
        if not isinstance(nickname, str) or not 1 <= len(nickname) <= 20 or len(nickname.encode("utf-8")) > 60 or any(ord(ch) < 32 or ord(ch) == 127 for ch in nickname):
            return response(False, "昵称须为 1–20 个可见字符")
        nickname = nickname.strip()
        if not nickname:
            return response(False, "昵称不能为空")
        with conn:
            conn.execute("UPDATE players SET nickname=? WHERE id=?", (nickname, account["player_id"]))
        return response(True, "昵称已更新", account["username"], nickname)
    username = data.get("username")
    password = data.get("password")
    device = data.get("device")
    platform = data.get("platform", "pc")
    if action not in ("register", "login") or not isinstance(username, str) or not USERNAME.fullmatch(username):
        return response(False, "账号须为 3–24 位英文字母、数字或下划线")
    if not isinstance(password, str) or not 8 <= len(password) <= 64 or len(password.encode("utf-8")) > 96:
        return response(False, "密码须为 8–64 个字符")
    if not isinstance(device, str) or not DEVICE.fullmatch(device):
        return response(False, "设备身份无效")
    if platform not in PLATFORMS:
        return response(False, "设备平台无效")
    key = username.casefold()
    now = int(time.time())
    attempts = [t for t in failures.get(key, []) if now - t < FAIL_WINDOW]
    failures[key] = attempts
    if len(attempts) >= MAX_FAILURES:
        return response(False, "尝试次数过多，请 15 分钟后重试")
    row = conn.execute("SELECT id, username, password_salt, password_hash FROM players WHERE username=?", (username,)).fetchone()
    if action == "register":
        if row:
            return response(False, "账号已存在")
        salt = secrets.token_bytes(16)
        digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, ITERATIONS)
        try:
            with conn:
                conn.execute("INSERT INTO players(username,password_salt,password_hash,created_at) VALUES(?,?,?,?)",
                             (username, salt, digest, now))
        except sqlite3.IntegrityError:
            return response(False, "账号已存在")
        failures.pop(key, None)
        return response(True, "注册成功，请登录", username, username)
    salt = row[2] if row else b"\0" * 16
    expected = row[3] if row else b"\0" * 32
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, ITERATIONS)
    if not row or not hmac.compare_digest(digest, expected):
        attempts.append(now)
        return response(False, "账号或密码错误")
    with conn:
        conn.execute("UPDATE players SET last_login_at=? WHERE id=?", (now, row[0]))
        token = secrets.token_hex(32)
        remember_token = secrets.token_hex(32)
        conn.execute("""INSERT INTO sessions(player_id,platform,token_hash,device,issued_at,remember_hash,remember_issued_at)
            VALUES(?,?,?,?,?,?,?) ON CONFLICT(player_id,platform) DO UPDATE SET
            token_hash=excluded.token_hash,device=excluded.device,issued_at=excluded.issued_at,
            remember_hash=excluded.remember_hash,remember_issued_at=excluded.remember_issued_at""",
            (row[0], platform, hashlib.sha256(token.encode("ascii")).digest(), device, now,
             hashlib.sha256(remember_token.encode("ascii")).digest(), now))
    failures.pop(key, None)
    nickname = conn.execute("SELECT nickname FROM players WHERE id=?", (row[0],)).fetchone()[0]
    return response(True, "登录成功", row[1], nickname or row[1], token, remember_token, platform)


class Handler(BaseHTTPRequestHandler):
    conn = None

    def do_POST(self):
        if self.path not in ("/account", "/session", "/deck-plaza") or self.client_address[0] != "127.0.0.1":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if not 0 < length <= (16384 if self.path == "/deck-plaza" else 2048):
            self.send_error(413)
            return
        try:
            data = json.loads(self.rfile.read(length))
            if self.path == "/deck-plaza":
                account = verify(self.conn, data.get("token")) if isinstance(data, dict) else response(False, "请求格式无效")
                result = deck_plaza_store.handle(self.conn, data, account) if account["ok"] else {"ok": False, "message": account["message"], "auth_required": True}
            else:
                result = handle(self.conn, data)
        except (ValueError, UnicodeError):
            result = response(False, "请求格式无效")
        body = json.dumps(result, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # Do not log account requests or credentials.


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--database", type=Path, default=Path.home() / ".local/share/multicolor-relay/data/players.sqlite3")
    parser.add_argument("--port", type=int, default=47864)
    args = parser.parse_args()
    Handler.conn = database(args.database)
    print(f"Account store listening on 127.0.0.1:{args.port}", flush=True)
    HTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
