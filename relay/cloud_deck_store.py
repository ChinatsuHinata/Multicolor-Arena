"""Ten private, revision-checked deck slots per player."""

import zlib

import deck_plaza_store as codes

LIMIT = 10


def initialize(conn):
    conn.execute("""CREATE TABLE IF NOT EXISTS cloud_decks (
        player_id INTEGER NOT NULL REFERENCES players(id),
        slot INTEGER NOT NULL CHECK(slot BETWEEN 1 AND 10),
        deck_code TEXT NOT NULL, revision INTEGER NOT NULL, identity INTEGER NOT NULL,
        PRIMARY KEY(player_id, slot))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS cloud_deck_revisions (
        player_id INTEGER PRIMARY KEY REFERENCES players(id), revision INTEGER NOT NULL)""")


def listing(conn, player_id):
    return [{"slot": slot, "deck_code": code, "revision": revision, "identity": identity}
            for slot, code, revision, identity in conn.execute(
                "SELECT slot,deck_code,revision,identity FROM cloud_decks WHERE player_id=? ORDER BY slot",
                (player_id,))]


def handle(conn, data, account):
    if not account.get("ok"):
        return {"ok": False, "auth_required": True, "message": "请先登录玩家账号"}
    if not isinstance(data, dict) or set(data) - {"action", "token", "slot", "revision", "deck_code"}:
        return {"ok": False, "message": "云端卡组请求格式无效"}
    action = data.get("action")
    if action not in ("list", "save", "delete"):
        return {"ok": False, "message": "云端卡组操作无效"}
    player_id = account["player_id"]
    initialize(conn)
    if action == "list":
        return {"ok": True, "limit": LIMIT, "decks": listing(conn, player_id)}
    slot, revision = data.get("slot"), data.get("revision")
    # Godot's JSON relay represents numbers as doubles, including whole numbers.
    if (type(slot) not in (int, float) or not 0 <= slot <= LIMIT or slot != int(slot)
            or type(revision) not in (int, float) or not 0 <= revision <= 2**53 - 1
            or revision != int(revision)):
        return {"ok": False, "message": "云端卡组槽或版本无效"}
    slot, revision = int(slot), int(revision)
    if action == "save":
        try:
            parts = codes.deck_parts(data.get("deck_code"))
            codes.deck_metadata(parts)
        except (ValueError, TypeError, UnicodeError, zlib.error):
            return {"ok": False, "message": "云端卡组代码无效"}
    with conn:
        if slot == 0 and action == "save":
            occupied = {row[0] for row in conn.execute(
                "SELECT slot FROM cloud_decks WHERE player_id=?", (player_id,))}
            slot = next((value for value in range(1, LIMIT + 1) if value not in occupied), 0)
            if not slot:
                return {"ok": False, "message": "十个云端卡组槽已满，请先释放一个槽位"}
        row = conn.execute("SELECT revision,identity FROM cloud_decks WHERE player_id=? AND slot=?",
                           (player_id, slot)).fetchone()
        if (row[0] if row else 0) != revision or (action == "delete" and row is None):
            return {"ok": False, "conflict": True, "message": "卡组已在其他设备更改，请同步后重新打开卡组"}
        # Revisions survive deletion, so an old device cannot overwrite a reused slot.
        conn.execute("""INSERT INTO cloud_deck_revisions VALUES (?,1)
            ON CONFLICT(player_id) DO UPDATE SET revision=revision+1""", (player_id,))
        next_revision = conn.execute("SELECT revision FROM cloud_deck_revisions WHERE player_id=?",
                                     (player_id,)).fetchone()[0]
        if action == "save":
            identity = row[1] if row else next_revision
            conn.execute("""INSERT INTO cloud_decks VALUES (?,?,?,?,?)
                ON CONFLICT(player_id,slot) DO UPDATE SET deck_code=excluded.deck_code,revision=excluded.revision""",
                         (player_id, slot, data["deck_code"], next_revision, identity))
        else:
            conn.execute("DELETE FROM cloud_decks WHERE player_id=? AND slot=?", (player_id, slot))
    return {"ok": True, "slot": slot, "limit": LIMIT, "decks": listing(conn, player_id)}
