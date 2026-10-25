"""Server-owned permissions, announcement grants and reviewed tutorial packages."""
import hashlib
import json
import re
import time
from pathlib import Path
import task_store

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "community_data"
if not DATA.exists():
    DATA = ROOT / "data" if (ROOT / "data/tutorial/catalog.json").exists() else ROOT.parent / "data"
ROLES = ("tournament_admin", "tutorial_editor")
MAX_LESSON_BYTES = 6 * 1024 * 1024


def integer(value, maximum=1000000):
    # Godot's JSON relay decodes numbers as floats before re-encoding them.
    return type(value) in (int, float) and 0 <= value <= maximum and int(value) == value


def initialize(conn):
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS community_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS community_roles(username TEXT COLLATE NOCASE,role TEXT,
            PRIMARY KEY(username,role));
        CREATE TABLE IF NOT EXISTS online_tutorials(id TEXT PRIMARY KEY,revision INTEGER NOT NULL,
            document TEXT NOT NULL,digest TEXT NOT NULL,updated_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS tutorial_submissions(id INTEGER PRIMARY KEY,author_id INTEGER NOT NULL,
            lesson_id TEXT NOT NULL,base_revision INTEGER NOT NULL,document TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',created_at INTEGER NOT NULL,reviewed_at INTEGER,
            note TEXT NOT NULL DEFAULT '');
        CREATE TABLE IF NOT EXISTS online_announcements(id TEXT PRIMARY KEY,document TEXT NOT NULL,
            coins INTEGER NOT NULL DEFAULT 0 CHECK(coins>=0));
    """)
    if not conn.execute("SELECT 1 FROM community_meta WHERE key='roles_initialized'").fetchone():
        conn.execute("INSERT OR IGNORE INTO community_roles VALUES('heixingboshi','tournament_admin')")
        conn.execute("INSERT INTO community_meta VALUES('roles_initialized','1')")
    catalogue = DATA / "tutorial/catalog.json"
    if catalogue.exists():
        for path in json.loads(catalogue.read_text(encoding="utf-8"))["lessons"]:
            source = DATA / path.removeprefix("res://data/")
            document = json.loads(source.read_text(encoding="utf-8"))
            body, digest = encode(document)
            conn.execute("INSERT OR IGNORE INTO online_tutorials VALUES(?,1,?,?,?)",
                         (document["id"], body, digest, int(time.time())))
    announcements = DATA / "announcements.json"
    if announcements.exists():
        catalogue = json.loads(announcements.read_text(encoding="utf-8"))
        for entry in catalogue.get("announcements", []):
            coins = entry.get("coins", 0)
            if type(coins) is not int or not 0 <= coins <= 1000000:
                raise ValueError("公告铜钱金额无效")
            conn.execute("INSERT OR IGNORE INTO online_announcements VALUES(?,?,?)",
                         (entry.get("id", entry["version"]), json.dumps(entry, ensure_ascii=False), coins))


def is_super(account):
    return account.get("ok") is True and account.get("username", "").casefold() == "bigcake"


def has_role(conn, account, role):
    return is_super(account) or bool(account.get("ok") and conn.execute(
        "SELECT 1 FROM community_roles WHERE username=? AND role=?", (account.get("username", ""), role)).fetchone())


def permissions(conn, account):
    return {"super_admin": is_super(account), **{role: has_role(conn, account, role) for role in ROLES}}


def encode(document):
    body = json.dumps(document, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return body, hashlib.sha256(body.encode("utf-8")).hexdigest()


def validate_lesson(document):
    if not isinstance(document, dict) or not isinstance(document.get("id"), str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", document["id"]):
        raise ValueError("教程 ID 仅支持字母、数字、下划线和短横线（1–80 字符）")
    if not isinstance(document.get("title"), str) or not 1 <= len(document["title"].strip()) <= 120:
        raise ValueError("教程标题须为 1–120 字符")
    if document.get("category", "beginner") not in ("beginner", "advanced", "leader"):
        raise ValueError("教程分类无效")
    steps = document.get("steps")
    if not isinstance(steps, dict) or not 1 <= len(steps) <= 2000 or document.get("start_step") not in steps:
        raise ValueError("教程节点或起点无效")
    if any(not isinstance(step, dict) for step in steps.values()):
        raise ValueError("教程节点必须为对象")
    body, digest = encode(document)
    if len(body.encode("utf-8")) > MAX_LESSON_BYTES:
        raise ValueError("教程包不能超过 6 MiB")
    return body, digest


def handle(conn, data, account):
    if not isinstance(data, dict):
        return {"ok": False, "message": "请求格式无效"}
    try:
        with conn:
            return dispatch(conn, data, account)
    except (ValueError, TypeError, OverflowError) as exc:
        return {"ok": False, "message": str(exc)}


def dispatch(conn, data, account):
    action = data.get("action")
    if action == "manifest":
        rows = conn.execute("SELECT id,revision,digest,document FROM online_tutorials ORDER BY id").fetchall()
        pending = conn.execute("SELECT COUNT(*) FROM tutorial_submissions WHERE status='pending'").fetchone()[0] if is_super(account) else 0
        return {"ok": True, "permissions": permissions(conn, account), "pending_reviews": pending, "lessons": [
            {"id": id, "revision": revision, "digest": digest, "title": json.loads(body)["title"]}
            for id, revision, digest, body in rows]}
    if action == "lesson":
        row = conn.execute("SELECT revision,digest,document FROM online_tutorials WHERE id=?", (str(data.get("id", "")),)).fetchone()
        if not row:
            raise ValueError("教程不存在")
        return {"ok": True, "revision": row[0], "digest": row[1], "document_text": row[2]}
    if action == "announcements":
        claimed = set()
        if account.get("ok"):
            claimed = {row[0] for row in conn.execute("SELECT period FROM task_rewards WHERE player_id=? AND category='announcement'", (account["player_id"],))}
        return {"ok": True, "announcements": [{**json.loads(body), "id": id, "coins": coins, "claimed": id in claimed}
            for id, body, coins in conn.execute("SELECT id,document,coins FROM online_announcements ORDER BY rowid DESC")]}
    if not account.get("ok"):
        return {"ok": False, "auth_required": True, "message": "请先登录玩家账号"}
    if action == "permissions":
        return {"ok": True, "permissions": permissions(conn, account)}
    if action == "claim_announcement":
        id = str(data.get("id", ""))
        row = conn.execute("SELECT coins FROM online_announcements WHERE id=?", (id,)).fetchone()
        if not row or row[0] <= 0:
            raise ValueError("此公告没有可领取的铜钱")
        granted = task_store.award(conn, account["player_id"], "announcement", id, "claim", row[0], int(time.time()))
        return {"ok": True, "claimed": True, "message": f"已领取 {row[0]} 铜钱" if granted else "此公告奖励已领取", "coins": row[0]}
    if action in ("roles", "set_role", "publish_announcement"):
        if not is_super(account):
            raise ValueError("仅 bigcake 可执行此操作")
        if action == "set_role":
            username, role, enabled = data.get("username"), data.get("role"), data.get("enabled")
            if not isinstance(username, str) or role not in ROLES or type(enabled) is not bool:
                raise ValueError("成员或权限无效")
            target = conn.execute("SELECT username FROM players WHERE username=? COLLATE NOCASE", (username.strip(),)).fetchone()
            if not target:
                raise ValueError("玩家账号不存在")
            if target[0].casefold() == "bigcake":
                raise ValueError("不能移除 bigcake 的超级管理员权限")
            if enabled:
                conn.execute("INSERT OR IGNORE INTO community_roles VALUES(?,?)", (target[0], role))
            else:
                conn.execute("DELETE FROM community_roles WHERE username=? AND role=?", (target[0], role))
        if action == "publish_announcement":
            entry, coins = data.get("entry"), data.get("coins", 0)
            if not isinstance(entry, dict) or any(not isinstance(entry.get(k), str) or not entry[k].strip() for k in ("id", "title", "body", "version")):
                raise ValueError("请填写公告 ID、版本、标题和正文")
            if len(entry["id"]) > 100 or len(entry["body"]) > 16000 or len(entry["title"]) > 120 or not integer(coins):
                raise ValueError("公告长度或奖励金额超出范围")
            # An ID identifies one grant forever, even when its text is corrected.
            entry = {k: entry[k] for k in ("id", "title", "body", "version")}
            entry["date"] = time.strftime("%Y-%m-%d", time.gmtime())
            conn.execute("INSERT INTO online_announcements VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET document=excluded.document,coins=excluded.coins",
                         (entry["id"], json.dumps(entry, ensure_ascii=False), int(coins)))
            return {"ok": True, "message": "公告及领取金额已发布；同一公告每个账号仅可领取一次"}
        return {"ok": True, "permissions": permissions(conn, account), "roles": [dict(zip(("username", "role"), row)) for row in conn.execute("SELECT username,role FROM community_roles ORDER BY username,role")]}
    if action in ("submit_lesson", "submissions", "submission", "review_lesson"):
        if not has_role(conn, account, "tutorial_editor"):
            raise ValueError("教程编辑器仅向教程群组成员开放")
        if action == "submit_lesson":
            document = data.get("document")
            body, _ = validate_lesson(document)
            base = data.get("base_revision", 0)
            current = conn.execute("SELECT revision FROM online_tutorials WHERE id=?", (document["id"],)).fetchone()
            if not integer(base) or base != (current[0] if current else 0):
                raise ValueError("线上教程已更新，请同步最新版本后重新编辑")
            if conn.execute("SELECT COUNT(*) FROM tutorial_submissions WHERE author_id=? AND status='pending'", (account["player_id"],)).fetchone()[0] >= 20:
                raise ValueError("最多同时提交 20 份待审核教程")
            conn.execute("INSERT INTO tutorial_submissions(author_id,lesson_id,base_revision,document,created_at) VALUES(?,?,?,?,?)",
                         (account["player_id"], document["id"], int(base), body, int(time.time())))
            return {"ok": True, "message": "已推送给 bigcake，批准后会同步给所有玩家"}
        if action in ("submission", "review_lesson"):
            if not integer(data.get("id"), 2**53 - 1) or data["id"] < 1:
                raise ValueError("提交编号无效")
            row = conn.execute("SELECT author_id,lesson_id,base_revision,document,status FROM tutorial_submissions WHERE id=?", (data.get("id"),)).fetchone()
            if not row or not is_super(account) and row[0] != account["player_id"]:
                raise ValueError("提交不存在或无权查看")
            if action == "submission":
                return {"ok": True, "document": json.loads(row[3]), "base_revision": row[2]}
            if not is_super(account):
                raise ValueError("仅 bigcake 可审核教程")
            if row[4] != "pending" or type(data.get("approve")) is not bool:
                raise ValueError("此提交已处理或审核参数无效")
            if data["approve"]:
                current = conn.execute("SELECT revision FROM online_tutorials WHERE id=?", (row[1],)).fetchone()
                if row[2] != (current[0] if current else 0):
                    raise ValueError("此提交基于旧版本，请作者同步后重新提交")
                body, digest = validate_lesson(json.loads(row[3]))
                conn.execute("INSERT INTO online_tutorials VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET revision=excluded.revision,document=excluded.document,digest=excluded.digest,updated_at=excluded.updated_at",
                             (row[1], row[2] + 1, body, digest, int(time.time())))
            conn.execute("UPDATE tutorial_submissions SET status=?,reviewed_at=?,note=? WHERE id=?",
                         ("approved" if data["approve"] else "rejected", int(time.time()), str(data.get("note", ""))[:1000], data["id"]))
        rows = conn.execute("""SELECT s.id,p.username,s.lesson_id,s.base_revision,s.status,s.created_at,s.note
            FROM tutorial_submissions s JOIN players p ON p.id=s.author_id
            WHERE (? OR s.author_id=?) ORDER BY s.id DESC LIMIT 100""", (is_super(account), account["player_id"])).fetchall()
        return {"ok": True, "permissions": permissions(conn, account), "message": "", "submissions": [dict(zip(("id", "author", "lesson_id", "base_revision", "status", "created_at", "note"), row)) for row in rows]}
    raise ValueError("社区操作无效")
