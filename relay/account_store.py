#!/usr/bin/env python3
"""Loopback-only SQLite account store for the Godot relay."""

import argparse
import base64
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
PASSWORD_CHANGE_LIFETIME = 120
INITIAL_ELO = 1000
ELO_K = 32
failures = {}
password_changes = {}


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
    if "elo" not in columns:
        conn.execute(f"ALTER TABLE players ADD COLUMN elo INTEGER NOT NULL DEFAULT {INITIAL_ELO}")
    for column in ("rank_step", "rank_stars", "rank_streak"):
        if column not in columns:
            conn.execute(f"ALTER TABLE players ADD COLUMN {column} INTEGER NOT NULL DEFAULT 0")
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
    conn.execute("""CREATE TABLE IF NOT EXISTS rating_matches (
        match_id TEXT PRIMARY KEY, player_a INTEGER NOT NULL, player_b INTEGER NOT NULL,
        created_at INTEGER NOT NULL, started_at INTEGER, status TEXT NOT NULL DEFAULT 'pending',
        winner INTEGER, elo_a INTEGER, elo_b INTEGER, delta_a INTEGER, delta_b INTEGER,
        FOREIGN KEY(player_a) REFERENCES players(id), FOREIGN KEY(player_b) REFERENCES players(id))""")
    match_columns = {row[1] for row in conn.execute("PRAGMA table_info(rating_matches)")}
    for column in ("rank_a", "rank_b"):
        if column not in match_columns:
            conn.execute(f"ALTER TABLE rating_matches ADD COLUMN {column} TEXT")
    conn.commit()
    return conn


def advance_rank(step, stars, streak, won):
    """Three wins start the bonus; promotion consumes all stars at the boundary."""
    streak = streak + 1 if won else 0
    if step >= 11:
        return 11, 0, streak
    if won:
        stars += 2 if streak >= 3 else 1
        if stars >= 3:
            step, stars = step + 1, 0
    elif step >= 2:
        if stars:
            stars -= 1
        elif step not in (2, 5):
            step, stars = step - 1, 2
    return step, stars, streak


def player_rank(conn, player_id):
    step, stars, streak, elo = conn.execute(
        "SELECT rank_step,rank_stars,rank_streak,elo FROM players WHERE id=?", (player_id,)).fetchone()
    tier = 4 if step >= 11 else 3 if step >= 8 else 2 if step >= 5 else 1 if step >= 2 else 0
    position = 0
    if tier == 4:
        position = 1 + conn.execute("""SELECT COUNT(*) FROM players WHERE rank_step=11
            AND (elo>? OR (elo=? AND id<?))""", (elo, elo, player_id)).fetchone()[0]
    return {"tier": tier, "level": (2, 5, 8, 11, 11)[tier] - step,
            "stars": stars, "streak": streak, "position": position}


def response(ok, message, username="", nickname="", token="", remember_token="", platform="", elo=None, rank=None):
    return {"ok": ok, "message": message, "username": username,
            "nickname": nickname, "token": token, "remember_token": remember_token,
            "platform": platform, **({"elo": elo} if elo is not None else {}),
            **({"rank": rank} if rank is not None else {})}


def verify(conn, token):
    if not isinstance(token, str) or not re.fullmatch(r"[a-f0-9]{64}", token, re.ASCII):
        return response(False, "登录凭据无效")
    digest = hashlib.sha256(token.encode("ascii")).digest()
    row = conn.execute("""SELECT p.id,p.username,p.nickname,s.token_hash,s.device,s.issued_at,s.platform,p.elo
        FROM sessions s JOIN players p ON p.id=s.player_id WHERE s.token_hash=?""", (digest,)).fetchone()
    if row and hmac.compare_digest(digest, row[3]) and time.time() - row[5] < SESSION_LIFETIME:
        player_id, username, nickname, _, device, _, platform, elo = row
        return {"ok": True, "username": username, "nickname": nickname or username,
                "device": device, "platform": platform, "player_id": player_id, "elo": elo,
                "rank": player_rank(conn, player_id)}
    return response(False, "登录已失效，请重新登录")


def remembered_session(conn, token, device):
    if not isinstance(token, str) or not re.fullmatch(r"[a-f0-9]{64}", token, re.ASCII):
        return None
    if not isinstance(device, str) or not DEVICE.fullmatch(device):
        return None
    digest = hashlib.sha256(token.encode("ascii")).digest()
    row = conn.execute("""SELECT p.id,p.username,p.nickname,s.remember_hash,s.remember_issued_at,s.platform,p.elo
        FROM sessions s JOIN players p ON p.id=s.player_id
        WHERE s.remember_hash=? AND s.device=?""", (digest, device)).fetchone()
    if row and row[3] is not None and hmac.compare_digest(digest, row[3]) and row[4] is not None and time.time() - row[4] < REMEMBER_LIFETIME:
        return row
    return None


def handle_password_change(conn, data):
    # Three existing RSA account packets keep even escaped 64-character
    # passwords within the relay's 245-byte plaintext limit. Nothing is saved
    # until the old password and both copies of the new password are verified.
    now = int(time.time())
    for ticket, pending in list(password_changes.items()):
        if now - pending["issued_at"] >= PASSWORD_CHANGE_LIFETIME:
            password_changes.pop(ticket, None)
    action = data["action"]
    password = data.get("password")
    if not isinstance(password, str) or not 8 <= len(password) <= 64 or len(password.encode("utf-8")) > 96:
        return response(False, "密码须为 8–64 个字符")
    if action == "pwa":
        secret = data.get("nickname")
        if not isinstance(secret, str) or not re.fullmatch(r"[A-Za-z0-9_-]{22}", secret, re.ASCII):
            return response(False, "修改密码验证请求无效")
        username = data.get("username")
        if not isinstance(username, str) or not USERNAME.fullmatch(username):
            return response(False, "账号须为 3–24 位英文字母、数字或下划线")
        key = username.casefold()
        attempts = [t for t in failures.get(key, []) if now - t < FAIL_WINDOW]
        failures[key] = attempts
        if len(attempts) >= MAX_FAILURES:
            return response(False, "尝试次数过多，请 15 分钟后重试")
        row = conn.execute("SELECT id,username,password_salt,password_hash FROM players WHERE username=?", (username,)).fetchone()
        digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), row[2] if row else b"\0" * 16, ITERATIONS)
        if not row or not hmac.compare_digest(digest, row[3]):
            attempts.append(now)
            return response(False, "账号或旧密码错误")
        # One pending change per account; tickets are short-lived and single-use.
        for ticket, pending in list(password_changes.items()):
            if pending["username"].casefold() == key:
                password_changes.pop(ticket, None)
        public_nonce = secrets.token_hex(16)
        # Responses travel through the existing relay in plaintext. A response
        # alone must not authorize a password change: the client contributes a
        # 128-bit secret inside its RSA-encrypted request.
        ticket = hashlib.sha256((secret + ":" + public_nonce).encode("ascii")).hexdigest()[:32]
        password_changes[ticket] = {"player_id": row[0], "username": row[1],
                                    "old_salt": row[2], "old_hash": row[3], "issued_at": now}
        return {"ok": True, "password_ticket": public_nonce}
    ticket = data.get("token")
    if not isinstance(ticket, str) or not re.fullmatch(r"[a-f0-9]{32}", ticket, re.ASCII):
        return response(False, "修改密码验证已失效，请重新提交")
    pending = password_changes.get(ticket)
    if pending is None:
        return response(False, "修改密码验证已失效，请重新提交")
    if action == "pw_set":
        if "new_hash" in pending:
            return response(False, "修改密码请求顺序无效")
        digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), pending["old_salt"], ITERATIONS)
        if hmac.compare_digest(digest, pending["old_hash"]):
            password_changes.pop(ticket, None)
            return response(False, "新密码不能与旧密码相同")
        pending["new_salt"] = secrets.token_bytes(16)
        pending["new_hash"] = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), pending["new_salt"], ITERATIONS)
        return {"ok": True}
    password_changes.pop(ticket, None)
    if "new_hash" not in pending:
        return response(False, "修改密码请求顺序无效")
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), pending["new_salt"], ITERATIONS)
    if not hmac.compare_digest(digest, pending["new_hash"]):
        return response(False, "两次输入的新密码不一致")
    with conn:
        updated = conn.execute("""UPDATE players SET password_salt=?,password_hash=?
            WHERE id=? AND password_hash=?""", (pending["new_salt"], pending["new_hash"],
                pending["player_id"], pending["old_hash"])).rowcount
        if not updated:
            return response(False, "密码已发生变化，请重新提交")
        conn.execute("DELETE FROM sessions WHERE player_id=?", (pending["player_id"],))
    failures.pop(pending["username"].casefold(), None)
    return response(True, "密码已修改，请使用新密码重新登录")


def handle(conn, data):
    if not isinstance(data, dict):
        return response(False, "请求格式无效")
    action = data.get("action")
    if action in ("register", "login") and isinstance(data.get("password"), dict):
        encoded = data["password"].get("b")
        if set(data["password"]) != {"b"} or not isinstance(encoded, str) or len(encoded) > 128:
            return response(False, "密码编码无效")
        try:
            data = {**data, "password": base64.b64decode(encoded, validate=True).decode("utf-8")}
        except (ValueError, UnicodeError):
            return response(False, "密码编码无效")
    if action in ("pwa", "pw_set", "pw_confirm"):
        return handle_password_change(conn, data)
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
        return response(True, "已自动登录", row[1], row[2] or row[1], token, remember_token, row[5], elo=row[6], rank=player_rank(conn, row[0]))
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
        return response(True, "昵称已更新", account["username"], nickname, elo=account["elo"], rank=account["rank"])
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
    nickname, elo = conn.execute("SELECT nickname,elo FROM players WHERE id=?", (row[0],)).fetchone()
    return response(True, "登录成功", row[1], nickname or row[1], token, remember_token, platform, elo=elo, rank=player_rank(conn, row[0]))


def handle_match(conn, data):
    """Trusted loopback relay lifecycle. Never dispatched by the public account API."""
    if not isinstance(data, dict):
        return {"ok": False, "message": "请求格式无效"}
    match_id = data.get("match_id")
    if not isinstance(match_id, str) or not re.fullmatch(r"[a-f0-9]{32}", match_id):
        return {"ok": False, "message": "匹配标识无效"}
    action = data.get("action")
    with conn:
        if action == "create":
            players = data.get("players")
            if (not isinstance(players, list) or len(players) != 2
                    or any(type(p) is not int for p in players) or players[0] == players[1]
                    or conn.execute("SELECT COUNT(*) FROM players WHERE id IN (?,?)", players).fetchone()[0] != 2):
                return {"ok": False, "message": "匹配玩家无效"}
            conn.execute("""INSERT OR IGNORE INTO rating_matches(match_id,player_a,player_b,created_at)
                VALUES(?,?,?,?)""", (match_id, *players, int(time.time())))
        row = conn.execute("""SELECT player_a,player_b,status,winner,elo_a,elo_b,delta_a,delta_b
            FROM rating_matches WHERE match_id=?""", (match_id,)).fetchone()
        if row is None or action == "create" and list(row[:2]) != players:
            return {"ok": False, "message": "匹配不存在或玩家不一致"}
        if action == "start" and row[2] == "pending":
            conn.execute("UPDATE rating_matches SET status='playing',started_at=? WHERE match_id=?",
                         (int(time.time()), match_id))
        elif action == "cancel" and row[2] in ("pending", "playing"):
            conn.execute("UPDATE rating_matches SET status='cancelled' WHERE match_id=?", (match_id,))
        elif action == "settle":
            winner = data.get("winner")
            if type(winner) is not int or winner not in (0, 1):
                return {"ok": False, "message": "胜负无效"}
            if row[2] == "settled":
                if winner != row[3]:
                    return {"ok": False, "message": "对局已按另一结果结算"}
            elif row[2] != "playing":
                return {"ok": False, "message": "对局尚未开始或已取消"}
            else:
                ratings = [conn.execute("SELECT elo FROM players WHERE id=?", (p,)).fetchone()[0] for p in row[:2]]
                exponent = max(-20.0, min(20.0, (ratings[1] - ratings[0]) / 400.0))
                expected = 1.0 / (1.0 + 10.0 ** exponent)
                delta = round(ELO_K * ((1 if winner == 0 else 0) - expected))
                next_ratings = [ratings[0] + delta, ratings[1] - delta]
                for actor, (player, rating) in enumerate(zip(row[:2], next_ratings)):
                    rank = conn.execute("SELECT rank_step,rank_stars,rank_streak FROM players WHERE id=?", (player,)).fetchone()
                    step, stars, streak = advance_rank(*rank, actor == winner)
                    conn.execute("UPDATE players SET elo=?,rank_step=?,rank_stars=?,rank_streak=? WHERE id=?",
                                 (rating, step, stars, streak, player))
                ranks = [json.dumps(player_rank(conn, player), ensure_ascii=False) for player in row[:2]]
                conn.execute("UPDATE rating_matches SET rank_a=?,rank_b=? WHERE match_id=?", (*ranks, match_id))
                conn.execute("""UPDATE rating_matches SET status='settled',winner=?,elo_a=?,elo_b=?,delta_a=?,delta_b=?
                    WHERE match_id=?""", (winner, *next_ratings, delta, -delta, match_id))
        elif action not in ("create", "start", "cancel"):
            return {"ok": False, "message": "未知匹配操作"}
        row = conn.execute("SELECT status,winner,elo_a,elo_b,delta_a,delta_b,rank_a,rank_b FROM rating_matches WHERE match_id=?",
                           (match_id,)).fetchone()
        return {"ok": True, "status": row[0], "winner": row[1], "ratings": list(row[2:4]), "deltas": list(row[4:6]),
                "ranks": [json.loads(value) if value else {} for value in row[6:8]]}


class Handler(BaseHTTPRequestHandler):
    conn = None

    def do_POST(self):
        if self.path not in ("/account", "/session", "/deck-plaza", "/match") or self.client_address[0] != "127.0.0.1":
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
            if self.path == "/match":
                result = handle_match(self.conn, data)
            elif self.path == "/deck-plaza":
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
