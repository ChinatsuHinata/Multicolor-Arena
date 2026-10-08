"""Text-only deck plaza, served by the loopback account store."""

import base64
import json
import re
import time
import zlib
from functools import lru_cache
from pathlib import Path

PAGE_SIZE = 6
MAX_CODE = 8192
MAX_PLAIN = 16384
IDENTIFIER = re.compile(r"[A-Za-z0-9_-]{1,64}\Z", re.ASCII)
RULES = ("unrestricted", "official", "official_spx", "test")
COLORS = ("红", "蓝", "绿", "黄", "黑")


@lru_cache(maxsize=1)
def catalogue():
    return json.loads(Path(__file__).with_name("deck_plaza_catalogue.json").read_text(encoding="utf-8"))["cards"]


def card_name_forms(value):
    """Match the client's printed-name rule for ノ in leader searches."""
    forms = [""]
    for index, part in enumerate(value.split("ノ")):
        forms = [prefix + joiner + part for prefix in forms
                 for joiner in (("",) if index == 0 else ("ノ", "", "之"))]
    return forms


def deck_metadata(parts):
    cards = catalogue()
    leader = cards.get(parts[1], {})
    if not leader.get("leader"):
        raise ValueError("自机无效")
    found_colors = set()
    ids = [parts[1]] + [item[0] if isinstance(item, list) else item for zone in parts[2:4] for item in zone]
    for card_id in ids:
        info = cards.get(card_id, {})
        if not info.get("constructible"):
            raise ValueError("卡组包含未知或不可构筑卡牌")
        if not info.get("exclude_colors"):
            found_colors.update(info["colors"])
    if len(parts) == 6:
        for card_id, art_id in parts[5].items():
            info = cards.get(card_id, {})
            if info.get("canonical") != card_id or art_id not in info.get("arts", []):
                raise ValueError("异画编号无效")
    search = [form for term in leader["search"] for form in card_name_forms(term)]
    return " ".join(search).casefold(), "".join(color for color in COLORS if color in found_colors)


def initialize(conn):
    conn.execute("""CREATE TABLE IF NOT EXISTS player_follows (
        follower_id INTEGER NOT NULL REFERENCES players(id),
        author_id INTEGER NOT NULL REFERENCES players(id),
        created_at INTEGER NOT NULL,
        PRIMARY KEY(follower_id,author_id), CHECK(follower_id != author_id))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS deck_posts (
        id INTEGER PRIMARY KEY,
        player_id INTEGER NOT NULL REFERENCES players(id),
        username TEXT NOT NULL, nickname TEXT NOT NULL,
        title TEXT NOT NULL, description TEXT NOT NULL, tags TEXT NOT NULL,
        deck_code TEXT NOT NULL, created_at INTEGER NOT NULL)""")
    conn.execute("CREATE INDEX IF NOT EXISTS deck_posts_latest ON deck_posts(created_at DESC,id DESC)")
    columns = {row[1] for row in conn.execute("PRAGMA table_info(deck_posts)")}
    for name in ("leader_search", "colors"):
        if name not in columns:
            conn.execute(f"ALTER TABLE deck_posts ADD COLUMN {name} TEXT NOT NULL DEFAULT ''")
    if "updated_at" not in columns:
        conn.execute("ALTER TABLE deck_posts ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0")
    # Reconcile existing posts against current card definitions; uploaders never
    # supply their own leader names or color classifications.
    for post_id, code, old_search, old_colors in conn.execute("SELECT id,deck_code,leader_search,colors FROM deck_posts").fetchall():
        try:
            search, colors = deck_metadata(deck_parts(code))
        except (ValueError, TypeError, UnicodeError, zlib.error):
            search, colors = "", ""
        if (search, colors) != (old_search, old_colors):
            conn.execute("UPDATE deck_posts SET leader_search=?,colors=? WHERE id=?", (search, colors, post_id))


def visible_text(value, maximum, empty=False, multiline=False):
    return (isinstance(value, str) and len(value) <= maximum
            and (empty or bool(value.strip()))
            and all(ord(ch) >= 32 and ord(ch) != 127 or multiline and ch in "\n\r\t" for ch in value))


def deck_parts(code):
    """Accept only the standard compact code schema, never paths or asset fields."""
    if not isinstance(code, str) or len(code.encode("utf-8")) > MAX_CODE:
        raise ValueError("卡组代码过长")
    if code.startswith("MA1Z:"):
        _, size, encoded = code.split(":", 2)
        if not re.fullmatch(r"[1-9][0-9]{0,4}", size) or not 0 < int(size) <= MAX_PLAIN:
            raise ValueError("压缩卡组代码长度无效")
        if not re.fullmatch(r"[A-Za-z0-9+/]+", encoded) or len(encoded) % 4 == 1:
            raise ValueError("压缩卡组代码格式错误")
        compressed = base64.b64decode(encoded + "=" * (-len(encoded) % 4), validate=True)
        inflater = zlib.decompressobj()
        raw = inflater.decompress(compressed, int(size) + 1)
        if len(raw) != int(size) or not inflater.eof or inflater.unused_data or inflater.unconsumed_tail:
            raise ValueError("压缩卡组代码格式错误")
        plain = raw.decode("utf-8")
    elif code.startswith("MA1:"):
        plain = code[4:]
    else:
        raise ValueError("请使用编辑器生成的卡组代码")
    parts = json.loads(plain)
    if not isinstance(parts, list) or len(parts) not in (4, 5, 6):
        raise ValueError("卡组代码格式错误")
    if not visible_text(parts[0], 40) or not isinstance(parts[1], str) or not IDENTIFIER.fullmatch(parts[1]):
        raise ValueError("套牌名称或自机无效")
    rule = parts[4] if len(parts) >= 5 else "unrestricted"
    for packed, maximum in ((parts[2], 70 if rule == "test" else 50), (parts[3], 10)):
        if not isinstance(packed, list) or len(packed) > maximum:
            raise ValueError("卡牌列表格式错误")
        count = 0
        for item in packed:
            card_id, amount = item, 1
            if isinstance(item, list) and len(item) == 2:
                card_id, amount = item
                if type(amount) not in (int, float) or not 2 <= amount <= maximum or int(amount) != amount:
                    raise ValueError("卡牌张数无效")
            if not isinstance(card_id, str) or not IDENTIFIER.fullmatch(card_id):
                raise ValueError("卡组代码仅接受卡牌编号")
            count += amount
        if count > maximum:
            raise ValueError("卡牌张数超过上限")
    if len(parts) >= 5 and parts[4] not in RULES:
        raise ValueError("卡组规则集无效")
    if len(parts) == 6:
        arts = parts[5]
        if not isinstance(arts, dict) or len(arts) > 256:
            raise ValueError("异画设置格式错误")
        for card_id, art_id in arts.items():
            if not IDENTIFIER.fullmatch(card_id) or not isinstance(art_id, str) or not IDENTIFIER.fullmatch(art_id):
                raise ValueError("异画仅接受编号，不接受图片或资源路径")
    return parts


def record(conn, row, account, detail=False):
    result = dict(zip(("id", "title", "tags", "deck_code", "nickname", "created_at"),
                      (row[0], row[1], row[2], row[3], row[5], row[6])))
    result["tags"] = json.loads(result["tags"])
    if detail:
        result["description"] = row[7]
    result["colors"] = list(row[8])
    result["owned"] = row[9] == account["player_id"]
    result["following"] = conn.execute("SELECT 1 FROM player_follows WHERE follower_id=? AND author_id=?",
                                       (account["player_id"], row[9])).fetchone() is not None
    return result


SELECT = "id,title,tags,deck_code,username,nickname,created_at,description,colors,player_id"


def color_query(value):
    term = "".join(value.split())
    for suffix in ("套牌", "卡组", "色"):
        if term.endswith(suffix):
            term = term[:-len(suffix)]
    if not term or any(color not in COLORS for color in term):
        if not value.strip():
            return []
        raise ValueError("颜色搜索请使用红、红蓝等颜色组合")
    return list(dict.fromkeys(term))


def like_term(value):
    return "%" + value.casefold().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"


def search_where(data, account):
    filters, values = [], []
    mine = data.get("mine", False)
    if not isinstance(mine, bool):
        raise ValueError("我的上传筛选无效")
    if mine:
        filters.append("player_id=?")
        values.append(account["player_id"])
    following = data.get("following", False)
    if not isinstance(following, bool):
        raise ValueError("关注筛选无效")
    if following:
        filters.append("player_id IN (SELECT author_id FROM player_follows WHERE follower_id=?)")
        values.append(account["player_id"])
    for field in ("leader", "tag"):
        term = data.get(field, "")
        if not visible_text(term, 60, empty=True):
            raise ValueError("搜索条件最多 60 个字符")
        if field == "leader" and term.strip():
            filters.append("leader_search LIKE ? ESCAPE '\\'")
            values.append(like_term(term.strip()))
        elif field == "tag":
            for tag in dict.fromkeys(part.strip() for part in re.split("[,，]", term) if part.strip()):
                filters.append("EXISTS (SELECT 1 FROM json_each(deck_posts.tags) AS tag WHERE tag.value LIKE ? ESCAPE '\\')")
                values.append(like_term(tag))
    color_text = data.get("color_text", "")
    if not visible_text(color_text, 30, empty=True):
        raise ValueError("颜色搜索命令过长")
    required = color_query(color_text)
    clicked = data.get("colors", [])
    if not isinstance(clicked, list) or len(clicked) > 5 or any(color not in COLORS for color in clicked):
        raise ValueError("颜色筛选无效")
    for color in set(required + clicked):
        filters.append("colors LIKE ?")
        values.append("%" + color + "%")
    return (" WHERE " + " AND ".join(filters)) if filters else "", values


def handle(conn, data, account):
    action = data.get("action")
    fields = {
        "upload": {"action", "token", "title", "description", "tags", "deck_code"},
        "edit": {"action", "token", "id", "title", "description", "tags", "deck_code"},
        "delete": {"action", "token", "id"},
        "list": {"action", "token", "page", "leader", "tag", "color_text", "colors", "mine", "following"},
        "detail": {"action", "token", "id"},
        "follow": {"action", "token", "id", "following"},
    }
    if not isinstance(action, str) or action not in fields or set(data) - fields[action]:
        return {"ok": False, "message": "套牌广场只接受文字和卡组代码，不接受资产或额外字段"}
    if action == "follow":
        post_id, following = data.get("id"), data.get("following")
        if type(post_id) not in (int, float) or not 0 < post_id <= 2**53 or int(post_id) != post_id or not isinstance(following, bool):
            return {"ok": False, "message": "关注请求无效"}
        row = conn.execute(f"SELECT {SELECT} FROM deck_posts WHERE id=?", (int(post_id),)).fetchone()
        if row is None:
            return {"ok": False, "message": "套牌已不存在，请刷新广场"}
        author_id = row[9]
        if author_id == account["player_id"]:
            return {"ok": False, "message": "不能关注自己"}
        with conn:
            if following:
                conn.execute("INSERT OR IGNORE INTO player_follows VALUES(?,?,?)", (account["player_id"], author_id, int(time.time())))
            else:
                conn.execute("DELETE FROM player_follows WHERE follower_id=? AND author_id=?", (account["player_id"], author_id))
        return {"ok": True, "message": "已关注作者" if following else "已取消关注", "deck": record(conn, row, account, detail=True)}
    if action in ("edit", "delete"):
        post_id = data.get("id")
        if type(post_id) not in (int, float) or not 0 < post_id <= 2**53 or int(post_id) != post_id:
            return {"ok": False, "message": "套牌编号无效"}
        owner = conn.execute("SELECT player_id FROM deck_posts WHERE id=?", (int(post_id),)).fetchone()
        if owner is None:
            return {"ok": False, "message": "套牌已不存在，请刷新广场"}
        if owner[0] != account["player_id"]:
            return {"ok": False, "message": "只能编辑或删除自己上传的套牌"}
        if action == "delete":
            with conn:
                conn.execute("DELETE FROM deck_posts WHERE id=? AND player_id=?", (int(post_id), account["player_id"]))
            return {"ok": True, "message": "已删除上传的套牌", "id": int(post_id)}
    if action in ("upload", "edit"):
        title, description, tags = data.get("title"), data.get("description"), data.get("tags")
        if not visible_text(title, 40):
            return {"ok": False, "message": "标题须为 1–40 个可见字符"}
        if not visible_text(description, 2000, empty=True, multiline=True):
            return {"ok": False, "message": "描述最多 2000 个字符"}
        if not isinstance(tags, list) or len(tags) > 10 or any(not visible_text(tag, 20) or "，" in tag or "," in tag for tag in tags):
            return {"ok": False, "message": "标签最多十个，每个 1–20 个字符，用中文逗号分隔"}
        try:
            parts = deck_parts(data.get("deck_code"))
            leader_search, colors = deck_metadata(parts)
        except (ValueError, TypeError, zlib.error, UnicodeError, OverflowError):
            return {"ok": False, "message": "卡组代码无效；只接受标准代码和异画编号"}
        # Use the published title as the local deck name too. Store only the
        # validated compact schema; unknown nested fields cannot survive it.
        parts[0] = title.strip()
        code = "MA1:" + json.dumps(parts, ensure_ascii=False, separators=(",", ":"))
        if len(code.encode("utf-8")) > MAX_CODE:
            return {"ok": False, "message": "卡组代码过长"}
        with conn:
            if action == "edit":
                conn.execute("""UPDATE deck_posts SET title=?,description=?,tags=?,deck_code=?,leader_search=?,colors=?,updated_at=?
                    WHERE id=? AND player_id=?""", (title.strip(), description.strip(), json.dumps([tag.strip() for tag in tags], ensure_ascii=False),
                    code, leader_search, colors, int(time.time()), int(post_id), account["player_id"]))
                updated = conn.execute(f"SELECT {SELECT} FROM deck_posts WHERE id=?", (int(post_id),)).fetchone()
                return {"ok": True, "message": "套牌修改已保存", "id": int(post_id), "deck": record(conn, updated, account, detail=True)}
            cursor = conn.execute("""INSERT INTO deck_posts
                (player_id,username,nickname,title,description,tags,deck_code,created_at,leader_search,colors)
                VALUES(?,?,?,?,?,?,?,?,?,?)""", (account["player_id"], account["username"], account["nickname"],
                    title.strip(), description.strip(), json.dumps([tag.strip() for tag in tags], ensure_ascii=False),
                    code, int(time.time()), leader_search, colors))
        return {"ok": True, "message": "套牌已上传到广场", "id": cursor.lastrowid}
    if action == "list":
        page = data.get("page", 0)
        if type(page) not in (int, float) or page < 0 or page > 1000000 or int(page) != page:
            return {"ok": False, "message": "页码无效"}
        try:
            where, values = search_where(data, account)
        except (ValueError, TypeError) as error:
            return {"ok": False, "message": "搜索条件无效：" + str(error)}
        count = conn.execute("SELECT COUNT(*) FROM deck_posts" + where, values).fetchone()[0]
        pages = max(1, (count + PAGE_SIZE - 1) // PAGE_SIZE)
        page = min(int(page), pages - 1)
        rows = conn.execute(f"SELECT {SELECT} FROM deck_posts{where} ORDER BY created_at DESC,id DESC LIMIT ? OFFSET ?",
                            (*values, PAGE_SIZE, page * PAGE_SIZE)).fetchall()
        return {"ok": True, "message": "", "decks": [record(conn, row, account) for row in rows], "page": page, "pages": pages, "total": count}
    post_id = data.get("id")
    if type(post_id) not in (int, float) or not 0 < post_id <= 2**53 or int(post_id) != post_id:
        return {"ok": False, "message": "套牌编号无效"}
    row = conn.execute(f"SELECT {SELECT} FROM deck_posts WHERE id=?", (int(post_id),)).fetchone()
    if row is None:
        return {"ok": False, "message": "套牌已不存在，请刷新广场"}
    return {"ok": True, "message": "", "deck": record(conn, row, account, detail=True)}
