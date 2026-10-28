"""Persistent competition lifecycle, Swiss/knockout pairing and timed actions."""
import math
import secrets
import time
import json
import hashlib
from collections import Counter
from pathlib import Path
import deck_plaza_store
import community_store
import tournament_rules
import tournament_limitless
from tournament_pairing import knockout_pairs, swiss_pairs

ORGANIZER_USERNAMES = frozenset(("bigcake", "heixingboshi"))
PAGE_SIZE = 6
MEMBER_PAGE_SIZE = 20
SELECT = "id,owner_id,title,description,phase,created_at"
CONFIG_COLUMNS = ("format", "swiss_rounds", "total_swiss_rounds", "round_number", "round_stage", "round_started_at", "round_interval", "timer_notice", "game_format", "start_at")
TOP_CUTS = {"swiss_top2": 2, "swiss_top4": 4, "swiss_top8": 8, "swiss_top16": 16}
FORMATS = ("swiss", *TOP_CUTS)
KNOCKOUT_STAGES = {2: "final", 4: "semifinal", 8: "quarterfinal", 16: "round_of_16"}
KNOCKOUT_PLACEMENTS = {stage: size // 2 + 1 for size, stage in KNOCKOUT_STAGES.items()}
GAME_FORMATS = tournament_rules.GAME_FORMATS
PAIR_PAGE_SIZE = 12
MAX_PLAYERS = 128


def initialize(conn):
    conn.execute("""CREATE TABLE IF NOT EXISTS tournaments (
        id INTEGER PRIMARY KEY, owner_id INTEGER NOT NULL REFERENCES players(id),
        title TEXT NOT NULL, description TEXT NOT NULL,
        phase TEXT NOT NULL DEFAULT 'registration', created_at INTEGER NOT NULL)""")
    conn.execute("""CREATE TABLE IF NOT EXISTS tournament_members (
        tournament_id INTEGER NOT NULL REFERENCES tournaments(id),
        player_id INTEGER NOT NULL REFERENCES players(id), joined_at INTEGER NOT NULL,
        checked_in_at INTEGER, in_roster INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(tournament_id,player_id))""")
    conn.execute("CREATE INDEX IF NOT EXISTS tournament_members_player ON tournament_members(player_id,tournament_id)")
    columns = {row[1] for row in conn.execute("PRAGMA table_info(tournaments)")}
    for name, definition in (("format", "TEXT NOT NULL DEFAULT 'swiss'"), ("swiss_rounds", "INTEGER NOT NULL DEFAULT 0"),
            ("total_swiss_rounds", "INTEGER NOT NULL DEFAULT 0"), ("round_number", "INTEGER NOT NULL DEFAULT 0"),
            ("round_stage", "TEXT NOT NULL DEFAULT ''"), ("round_started_at", "INTEGER NOT NULL DEFAULT 0"),
            ("round_interval", "INTEGER NOT NULL DEFAULT 0"), ("timer_notice", "TEXT NOT NULL DEFAULT ''"),
            ("game_format", "INTEGER NOT NULL DEFAULT 2"), ("start_at", "INTEGER NOT NULL DEFAULT 0")):
        if name not in columns:
            conn.execute(f"ALTER TABLE tournaments ADD COLUMN {name} {definition}")
    if "seed" not in {row[1] for row in conn.execute("PRAGMA table_info(tournament_members)")}:
        conn.execute("ALTER TABLE tournament_members ADD COLUMN seed INTEGER NOT NULL DEFAULT 0")
    conn.execute("""CREATE TABLE IF NOT EXISTS tournament_rounds (
        tournament_id INTEGER NOT NULL, number INTEGER NOT NULL, stage TEXT NOT NULL,
        started_at INTEGER NOT NULL, PRIMARY KEY(tournament_id,number))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS tournament_pairings (
        id INTEGER PRIMARY KEY, tournament_id INTEGER NOT NULL, round_number INTEGER NOT NULL,
        table_number INTEGER NOT NULL, player_a INTEGER NOT NULL, player_b INTEGER,
        result INTEGER, report_a INTEGER, report_b INTEGER, revision INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT '', match_id TEXT NOT NULL UNIQUE,
        game_claimed INTEGER NOT NULL DEFAULT 0, game_heartbeat INTEGER NOT NULL DEFAULT 0,
        UNIQUE(tournament_id,round_number,table_number))""")
    if "game_heartbeat" not in {row[1] for row in conn.execute("PRAGMA table_info(tournament_pairings)")}:
        conn.execute("ALTER TABLE tournament_pairings ADD COLUMN game_heartbeat INTEGER NOT NULL DEFAULT 0")
    conn.execute("""CREATE TABLE IF NOT EXISTS tournament_schedules (
        id INTEGER PRIMARY KEY, tournament_id INTEGER NOT NULL, action TEXT NOT NULL,
        due_at INTEGER NOT NULL, expected_round INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'scheduled',
        message TEXT NOT NULL DEFAULT '')""")
    conn.execute("CREATE INDEX IF NOT EXISTS tournament_schedules_due ON tournament_schedules(status,due_at)")
    conn.execute("""CREATE TABLE IF NOT EXISTS tournament_decklists (
        tournament_id INTEGER NOT NULL, round_number INTEGER NOT NULL, player_id INTEGER NOT NULL,
        game_format INTEGER NOT NULL, deck_json TEXT NOT NULL, signature TEXT NOT NULL,
        submitted_at INTEGER NOT NULL, PRIMARY KEY(tournament_id,round_number,player_id))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS tournament_decklist_rules (
        tournament_id INTEGER NOT NULL, round_number INTEGER NOT NULL,
        fixed_deck INTEGER NOT NULL DEFAULT 0, deadline_at INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(tournament_id,round_number))""")
    tournament_rules.initialize(conn)
    tournament_limitless.initialize(conn)


def config(conn, tournament_id):
    return dict(zip(CONFIG_COLUMNS, conn.execute("SELECT " + ",".join(CONFIG_COLUMNS) + " FROM tournaments WHERE id=?",
                                                (tournament_id,)).fetchone()))


def can_create(account, conn):
    return community_store.has_role(conn, account, "tournament_admin")


def can_manage(conn, account, owner):
    return community_store.is_super(account, conn) or can_create(account, conn) and owner == account["player_id"]


def error(message):
    return {"ok": False, "message": message}


def integer(value, minimum=0):
    return type(value) in (int, float) and minimum <= value <= 2**53 - 1 and int(value) == value


def checked_deck(deck, game_format):
    """Validate actual cards using exported game rules, never a client hash."""
    if not isinstance(deck, dict) or set(deck) - {"id", "name", "leader", "main", "side", "rule_set", "art_overrides"}:
        raise ValueError("牌表格式无效")
    if not isinstance(deck.get("id"), str) or not 1 <= len(deck["id"]) <= 128:
        raise ValueError("卡组标识无效")
    if not deck_plaza_store.visible_text(deck.get("name"), 40):
        raise ValueError("卡组名称须为 1–40 个可见字符")
    if deck.get("rule_set", "unrestricted") not in deck_plaza_store.RULES:
        raise ValueError("比赛不接受模组或未知规则集卡组")
    if not isinstance(deck.get("leader"), str) or any(not isinstance(deck.get(zone), list) for zone in ("main", "side")):
        raise ValueError("自机或主副卡组格式无效")
    if len(deck["main"]) != 50 or len(deck["side"]) > 10:
        raise ValueError("比赛主卡组需要 50 张，备牌最多 10 张")
    ids = [deck["leader"], *deck["main"], *deck["side"]]
    cards = deck_plaza_store.catalogue()
    if any(not isinstance(card, str) or card not in cards for card in ids):
        raise ValueError("牌表包含未知卡牌")
    arts = deck.get("art_overrides", {})
    if not isinstance(arts, dict) or len(arts) > 256 or any(
            card not in cards or cards[card]["canonical"] != card or not isinstance(art, str) or art not in cards[card]["arts"]
            for card, art in arts.items()):
        raise ValueError("异画编号无效")
    if game_format in (4, 5):
        fixed = json.loads(Path(deck_plaza_store.__file__).with_name("deck_plaza_catalogue.json").read_text(encoding="utf-8"))["fixed_decks"][str(game_format)]
        if deck["leader"] != fixed["leader"] or Counter(deck["main"]) != Counter(fixed["main"]) or deck["side"] or arts:
            raise ValueError("娱乐赛制只能使用指定固定卡组")
    else:
        if not cards[deck["leader"]]["leader"] or any(not cards[card].get("match_allowed", False) for card in ids):
            raise ValueError("牌表包含不能用于本比赛的自机或卡牌")
        names = Counter(cards[card]["name_key"] for card in deck["main"] + deck["side"])
        if cards[deck["leader"]]["name_key"] in names:
            raise ValueError("主副卡组不能包含所选自机的同名牌")
        for card in deck["main"] + deck["side"]:
            limit = cards[card]["match_limit"]
            if limit >= 0 and names[cards[card]["name_key"]] > limit:
                raise ValueError(f"同名牌超过 {limit} 张上限：{cards[card]['name_key']}")
    normalized = [cards[deck["leader"]]["canonical"],
                  *[sorted(Counter(cards[card]["canonical"] for card in deck[zone]).items()) for zone in ("main", "side")]]
    signature = hashlib.sha256(json.dumps(normalized, ensure_ascii=True, separators=(",", ":")).encode()).hexdigest()
    return signature


def decklist_rule(conn, tid, number):
    row = conn.execute("SELECT fixed_deck,deadline_at FROM tournament_decklist_rules WHERE tournament_id=? AND round_number=?",
                       (tid, max(1, number))).fetchone()
    return {"round_number": max(1, number), "fixed_deck": bool(row and row[0]), "deadline_at": row[1] if row else 0}


def configure_decklist(conn, tid, data):
    conn.execute("UPDATE tournaments SET id=id WHERE id=?", (tid,))
    phase, current = conn.execute("SELECT phase,round_number FROM tournaments WHERE id=?", (tid,)).fetchone()
    number, fixed, deadline = data.get("round_number"), data.get("fixed_deck"), data.get("deadline_at", 0)
    if not integer(number, 1) or not max(1, current) <= number <= max(1, current + 1):
        raise ValueError("只能设置本轮或下一轮的牌表规则，请刷新比赛页面")
    if type(fixed) is not bool or not integer(deadline):
        raise ValueError("牌表规则或截止时间无效")
    if phase == "complete":
        raise ValueError("比赛已结束")
    deadline = int(deadline) if fixed else 0
    previous = decklist_rule(conn, tid, number)
    if previous["fixed_deck"] == fixed and previous["deadline_at"] == deadline:
        return "本轮牌表规则未改变"
    if previous["fixed_deck"] and int(time.time()) >= previous["deadline_at"]:
        raise ValueError("牌表已截止，不能更改本轮固定卡组规则或截止时间")
    if conn.execute("""SELECT 1 FROM tournament_pairings WHERE tournament_id=? AND round_number=?
        AND player_b IS NOT NULL AND (game_claimed=1 OR game_heartbeat>0 OR result IS NOT NULL OR source='awaiting_limitless')""", (tid, number)).fetchone():
        raise ValueError("本轮已有对局开始或结果，不能更改固定卡组规则")
    if fixed and not int(time.time()) < deadline <= int(time.time()) + 366 * 86400:
        raise ValueError("请设置未来一年内的牌表截止时间")
    conn.execute("""INSERT INTO tournament_decklist_rules VALUES(?,?,?,?)
        ON CONFLICT(tournament_id,round_number) DO UPDATE SET fixed_deck=excluded.fixed_deck,deadline_at=excluded.deadline_at""",
        (tid, int(number), int(fixed), deadline))
    return "本轮牌表规则已保存"


def decklist_view(conn, tid, player):
    phase, number, game_format = conn.execute("SELECT phase,round_number,game_format FROM tournaments WHERE id=?", (tid,)).fetchone()
    member = conn.execute("SELECT in_roster FROM tournament_members WHERE tournament_id=? AND player_id=?", (tid, player)).fetchone()
    pair = conn.execute("SELECT player_b,result,source,game_claimed FROM tournament_pairings WHERE tournament_id=? AND round_number=? AND (player_a=? OR player_b=?)", (tid, number, player, player)).fetchone()
    available = bool(member and (phase in ("registration", "checkin") or phase == "locked" and member[0] or
                     phase == "running" and member[0] and pair and pair[0] is not None and pair[1] is None and pair[2] != "awaiting_limitless" and not pair[3]))
    number = max(1, number)
    rule = decklist_rule(conn, tid, number)
    required = rule["fixed_deck"] and game_format not in (4, 5)
    closed = required and int(time.time()) >= rule["deadline_at"]
    row = conn.execute("SELECT deck_json,submitted_at,game_format FROM tournament_decklists WHERE tournament_id=? AND round_number=? AND player_id=?", (tid, number, player)).fetchone()
    return {**rule, "game_format": game_format, "required": required, "closed": closed,
            "can_submit": available and required and not closed,
            "can_enter": not required or closed and row is not None,
            "submitted": row is not None, "deck": json.loads(row[0]) if row else {},
            "submitted_at": row[1] if row else 0}


def submit_decklist(conn, tid, player, data):
    # Serialize submissions so each successful update stores a complete, validated list.
    with conn:
        conn.execute("UPDATE tournaments SET id=id WHERE id=?", (tid,))
        view = decklist_view(conn, tid, player)
        if not integer(data.get("round_number"), 1) or data["round_number"] != view["round_number"]:
            raise ValueError("牌表轮次已变化，请刷新比赛页面")
        signature = checked_deck(data.get("deck"), view["game_format"])
        if not view["required"]:
            raise ValueError("本轮无需提交牌表")
        existing = conn.execute("SELECT signature FROM tournament_decklists WHERE tournament_id=? AND round_number=? AND player_id=?", (tid, view["round_number"], player)).fetchone()
        now = int(time.time())
        if not view["can_submit"] or now >= view["deadline_at"]:
            if existing and existing[0] == signature:
                return "本轮牌表已提交并锁定"
            if now >= view["deadline_at"]:
                raise ValueError("本轮牌表已截止，不能提交或更改")
            raise ValueError("当前不能提交牌表，请确认参赛资格和本轮对阵")
        conn.execute("""INSERT INTO tournament_decklists VALUES(?,?,?,?,?,?,?)
            ON CONFLICT(tournament_id,round_number,player_id) DO UPDATE SET
            game_format=excluded.game_format,deck_json=excluded.deck_json,
            signature=excluded.signature,submitted_at=excluded.submitted_at""",
            (tid, view["round_number"], player, view["game_format"], json.dumps(data["deck"], ensure_ascii=False), signature, now))
    return "牌表合规检查通过，已保存本轮卡组；截止前可继续更改"


def record(conn, row, account):
    tournament_id, owner, title, description, phase, created = row
    member = conn.execute("SELECT checked_in_at,in_roster FROM tournament_members WHERE tournament_id=? AND player_id=?",
                          (tournament_id, account["player_id"])).fetchone()
    counts = conn.execute("""SELECT COUNT(*),COUNT(checked_in_at),COALESCE(SUM(in_roster),0)
        FROM tournament_members WHERE tournament_id=?""", (tournament_id,)).fetchone()
    settings = config(conn, tournament_id)
    pending = conn.execute("SELECT COUNT(*) FROM tournament_pairings WHERE tournament_id=? AND round_number=? AND result IS NULL",
                           (tournament_id, settings["round_number"])).fetchone()[0]
    return {"id": tournament_id, "title": title, "description": description, "phase": phase, **settings, **tournament_rules.config(conn, tournament_id),
            "pairing_source": "limitless" if tournament_limitless.bound(conn, tournament_id) else "local",
            "limitless_admission": tournament_limitless.admission(conn, tournament_id, account["player_id"]),
            "super_admin": community_store.is_super(account, conn),
            "pending_matches": pending,
            "created_at": created, "owned": can_manage(conn, account, owner),
            "joined": member is not None, "checked_in": member is not None and member[0] is not None,
            "in_roster": member is not None and bool(member[1]),
            "member_count": counts[0], "checkin_count": counts[1], "roster_count": counts[2]}


def detail(conn, row, account, page=0, roster_only=False, message="", pairing_page=0, standing_page=0, pairing_round=0, query=None):
    condition = " AND m.in_roster=1" if roster_only else ""
    count = conn.execute("SELECT COUNT(*) FROM tournament_members m WHERE m.tournament_id=?" + condition,
                         (row[0],)).fetchone()[0]
    pages = max(1, (count + MEMBER_PAGE_SIZE - 1) // MEMBER_PAGE_SIZE)
    page = min(page, pages - 1)
    members = conn.execute("""SELECT p.nickname,m.player_id,m.checked_in_at,m.in_roster,m.seed
        FROM tournament_members m JOIN players p ON p.id=m.player_id WHERE m.tournament_id=?""" + condition +
        " ORDER BY m.joined_at,m.player_id LIMIT ? OFFSET ?", (row[0], MEMBER_PAGE_SIZE, page * MEMBER_PAGE_SIZE)).fetchall()
    competition = record(conn, row, account)
    selected_round = pairing_round or competition["round_number"]
    round_row = conn.execute("SELECT number,stage,stage_index,stage_round FROM tournament_rounds WHERE tournament_id=? AND number=?",
                             (row[0], selected_round)).fetchone()
    standings = standings_for(conn, row[0])
    standing_pages = max(1, math.ceil(len(standings) / MEMBER_PAGE_SIZE))
    standing_page = min(standing_page, standing_pages - 1)
    pairing_count = conn.execute("SELECT COUNT(*) FROM tournament_pairings WHERE tournament_id=? AND round_number=?",
                                (row[0], selected_round)).fetchone()[0]
    pairing_pages = max(1, math.ceil(pairing_count / PAIR_PAGE_SIZE))
    pairing_page = min(pairing_page, pairing_pages - 1)
    pairings = conn.execute("SELECT id FROM tournament_pairings WHERE tournament_id=? AND round_number=? ORDER BY table_number LIMIT ? OFFSET ?",
                           (row[0], selected_round, PAIR_PAGE_SIZE, pairing_page * PAIR_PAGE_SIZE)).fetchall()
    mine = conn.execute("""SELECT id FROM tournament_pairings WHERE tournament_id=? AND round_number=?
        AND (player_a=? OR player_b=?)""", (row[0], competition["round_number"], account["player_id"], account["player_id"])).fetchone()
    schedules = conn.execute("""SELECT id,action,due_at,expected_round,status,message FROM tournament_schedules
        WHERE tournament_id=? ORDER BY id DESC LIMIT 20""", (row[0],)).fetchall()
    public_standings = [{key: value for key, value in entry.items() if key not in ("player_id",)}
                        for entry in standings[standing_page * MEMBER_PAGE_SIZE:(standing_page + 1) * MEMBER_PAGE_SIZE]]
    return {"ok": True, "message": message, "tournament": competition,
            "decklist": decklist_view(conn, row[0], account["player_id"]),
            "decklist_rules": [decklist_rule(conn, row[0], number) for number in range(max(1, competition["round_number"]), max(1, competition["round_number"] + 1) + 1)],
            "pairing_round": selected_round, "round_info": dict(zip(("number", "stage", "stage_index", "stage_round"), round_row)) if round_row else {},
            "limitless": tournament_limitless.view(conn, row[0], {**(query or {}), "owned": competition["owned"]}),
            "join_requests": tournament_limitless.requests_view(conn, row[0], int((query or {}).get("request_page", 0))) if competition["owned"] else {},
            "standings": public_standings, "standing_page": standing_page, "standing_pages": standing_pages,
            "pairings": [pairing_record(conn, pair[0], account) for pair in pairings],
            "pairing_page": pairing_page, "pairing_pages": pairing_pages,
            "my_pairing": pairing_record(conn, mine[0], account) if mine else {},
            "schedules": [dict(zip(("id", "action", "due_at", "expected_round", "status", "message"), task)) for task in schedules],
            "members": [{"nickname": name or (f"选手{seed:02d}" if seed else "未设置昵称"), "self": player == account["player_id"],
                         "checked_in": stamp is not None, "in_roster": bool(roster)}
                        for name, player, stamp, roster, seed in members],
            "member_page": page, "member_pages": pages, "member_total": count, "roster_only": roster_only}


def handle_group(conn, data, account):
    if not account.get("ok"):
        return {"ok": False, "auth_required": True, "message": "请先登录玩家账号"}
    if not isinstance(data, dict):
        return error("请求格式无效")
    open_due_checkins(conn)
    action = data.get("action")
    if action not in ("list", "create", "detail", "join", "leave", "checkin", "open_checkin", "close_checkin"):
        return error("比赛操作无效")
    if action == "create":
        if not can_create(account, conn):
            return error("当前仅主办方可以创建比赛")
        title, description = data.get("title"), data.get("description", "")
        if not isinstance(title, str) or not 1 <= len(title.strip()) <= 40:
            return error("比赛名称须为 1–40 个字符")
        if not isinstance(description, str) or len(description) > 2000:
            return error("群组说明最多 2000 个字符")
        with conn:
            cursor = conn.execute("INSERT INTO tournaments(owner_id,title,description,created_at) VALUES(?,?,?,?)",
                                  (account["player_id"], title.strip(), description.strip(), int(time.time())))
        row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=?", (cursor.lastrowid,)).fetchone()
        return detail(conn, row, account, message="比赛群组已创建")
    if action == "list":
        page = data.get("page", 0)
        if not integer(page):
            return error("页码无效")
        count = conn.execute("SELECT COUNT(*) FROM tournaments WHERE phase!='deleted'").fetchone()[0]
        pages = max(1, (count + PAGE_SIZE - 1) // PAGE_SIZE)
        page = min(int(page), pages - 1)
        rows = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE phase!='deleted' ORDER BY id DESC LIMIT ? OFFSET ?",
                            (PAGE_SIZE, page * PAGE_SIZE)).fetchall()
        return {"ok": True, "message": "", "can_create": can_create(account, conn),
                "super_admin": community_store.is_super(account, conn),
                "tournaments": [record(conn, row, account) for row in rows], "page": page, "pages": pages, "total": count}
    tournament_id = data.get("id")
    if not integer(tournament_id, 1):
        return error("比赛编号无效")
    tournament_id = int(tournament_id)
    row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=? AND phase!='deleted'", (tournament_id,)).fetchone()
    if row is None:
        return {**error("比赛不存在，请刷新列表"), "tournament_missing": True}
    if action == "detail":
        page, roster_only = data.get("member_page", 0), data.get("roster_only", False)
        if not integer(page) or type(roster_only) is not bool:
            return error("成员筛选或页码无效")
        return detail(conn, row, account, int(page), roster_only)
    player_id, phase = account["player_id"], row[4]
    member = conn.execute("SELECT checked_in_at FROM tournament_members WHERE tournament_id=? AND player_id=?",
                          (tournament_id, player_id)).fetchone()
    if tournament_limitless.bound(conn, tournament_id):
        state = tournament_limitless.admission(conn, tournament_id, player_id)
        if action == "leave" and state.get("status") == "pending":
            with conn:
                conn.execute("UPDATE tournament_limitless_requests SET status='withdrawn' WHERE tournament_id=? AND player_id=?", (tournament_id, player_id))
            return detail(conn, row, account, message="已撤回加入申请")
        if action == "join" and member is None:
            if not state.get("can_join") and state.get("status") != "pending":
                return error(state["reason"])
            if state.get("started"):
                try:
                    with conn:
                        message = tournament_limitless.apply_join(conn, tournament_id, player_id)
                    return detail(conn, row, account, message=message)
                except ValueError as exc:
                    return error(str(exc))
    if action in ("open_checkin", "close_checkin"):
        if not can_manage(conn, account, row[1]):
            return error("仅主办方可以管理赛前签到")
        if action == "open_checkin":
            start_at = config(conn, tournament_id)["start_at"]
            if not start_at or int(time.time()) < start_at:
                return error("比赛时间尚未到达，目前仅开放报名")
            if phase == "checkin":
                return detail(conn, row, account, message="比赛签到已开启")
        expected = "registration" if action == "open_checkin" else "checkin"
        if phase != expected:
            return error("比赛状态已变化，请刷新后重试")
        with conn:
            if action == "close_checkin":
                conn.execute("UPDATE tournament_members SET in_roster=(checked_in_at IS NOT NULL) WHERE tournament_id=?",
                             (tournament_id,))
            conn.execute("UPDATE tournaments SET phase=? WHERE id=?",
                         ("checkin" if action == "open_checkin" else "locked", tournament_id))
        message = "赛前签到已开启" if action == "open_checkin" else "签到已结束，已签到玩家已纳入参赛名单"
    else:
        if phase not in ("registration", "checkin"):
            return error("签到已结束，参赛名单已确定")
        if action == "join":
            start_at = config(conn, tournament_id)["start_at"]
            if not start_at:
                return error("主办方尚未指定比赛时间，暂不能报名")
            if int(time.time()) >= start_at or phase != "registration":
                return error("已到比赛时间，报名已截止；已报名玩家可签到")
            if member is None and conn.execute("SELECT COUNT(*) FROM tournament_members WHERE tournament_id=?", (tournament_id,)).fetchone()[0] >= MAX_PLAYERS:
                return error("比赛群组最多 128 人")
            with conn:
                conn.execute("INSERT OR IGNORE INTO tournament_members(tournament_id,player_id,joined_at) VALUES(?,?,?)",
                             (tournament_id, player_id, int(time.time())))
            message = "已加入比赛群组；赛前还需签到"
        elif action == "leave":
            if member is None:
                return error("你尚未加入比赛群组")
            with conn:
                conn.execute("DELETE FROM tournament_members WHERE tournament_id=? AND player_id=?", (tournament_id, player_id))
                conn.execute("DELETE FROM tournament_limitless_players WHERE tournament_id=? AND player_id=?", (tournament_id, player_id))
                conn.execute("UPDATE tournament_limitless_requests SET status='withdrawn' WHERE tournament_id=? AND player_id=?", (tournament_id, player_id))
            message = "已退出比赛群组"
        else:
            if member is None:
                return error("请先加入比赛群组")
            if phase != "checkin":
                return error("赛前签到尚未开启")
            with conn:
                conn.execute("""UPDATE tournament_members SET checked_in_at=COALESCE(checked_in_at,?)
                    WHERE tournament_id=? AND player_id=?""", (int(time.time()), tournament_id, player_id))
            message = "赛前签到成功"
    row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=?", (tournament_id,)).fetchone()
    return detail(conn, row, account, message=message)


def standings_for(conn, tournament_id):
    if tournament_limitless.bound(conn, tournament_id):
        return tournament_limitless.local_standings(conn, tournament_id)
    if tournament_rules.config(conn, tournament_id)["stages"]:
        if conn.execute("SELECT phase FROM tournaments WHERE id=?", (tournament_id,)).fetchone()[0] == "complete":
            return tournament_rules.final_standings(conn, tournament_id)
        return tournament_rules.standings(conn, tournament_id)
    rows = conn.execute("""SELECT m.player_id,p.nickname,m.seed FROM tournament_members m
        JOIN players p ON p.id=m.player_id WHERE m.tournament_id=? AND m.in_roster=1 ORDER BY m.seed,m.player_id""",
        (tournament_id,)).fetchall()
    players = {player: {"player_id": player, "nickname": name or f"选手{seed:02d}", "seed": seed, "points": 0,
                        "wins": 0, "draws": 0, "losses": 0, "byes": 0, "buchholz": 0} for player, name, seed in rows}
    opponents = {player: [] for player in players}
    for a, b, result in conn.execute("""SELECT p.player_a,p.player_b,p.result FROM tournament_pairings p
        JOIN tournament_rounds r ON r.tournament_id=p.tournament_id AND r.number=p.round_number
        WHERE p.tournament_id=? AND r.stage='swiss' AND p.result IS NOT NULL""", (tournament_id,)):
        if a not in players or b is not None and b not in players:
            continue
        if b is None:
            players[a]["points"] += 3
            players[a]["byes"] += 1
            continue
        opponents[a].append(b)
        opponents[b].append(a)
        for player, actor in ((a, 0), (b, 1)):
            key = "draws" if result == -1 else "wins" if result == actor else "losses"
            players[player][key] += 1
            players[player]["points"] += 1 if result == -1 else 3 if result == actor else 0
    for player, faced in opponents.items():
        players[player]["buchholz"] = sum(players[other]["points"] for other in faced)
    ordered = sorted(players.values(), key=lambda row: (-row["points"], -row["buchholz"], -row["wins"], row["seed"], row["player_id"]))
    for rank, entry in enumerate(ordered, 1):
        entry["rank"] = rank
    # Keep Swiss seeding visible alongside the knockout placement.
    for a, b, result, stage in conn.execute("""SELECT p.player_a,p.player_b,p.result,r.stage FROM tournament_pairings p
        JOIN tournament_rounds r ON r.tournament_id=p.tournament_id AND r.number=p.round_number
        WHERE p.tournament_id=? AND r.stage!='swiss' AND p.result IN (0,1)
        ORDER BY r.number,p.table_number""", (tournament_id,)):
        winner, loser = (a, b) if result == 0 else (b, a)
        players[loser]["placement"] = KNOCKOUT_PLACEMENTS[stage]
        if stage == "final":
            players[winner]["placement"] = 1
    return ordered


def pairing_record(conn, pairing_id, account):
    row = conn.execute("""SELECT id,table_number,player_a,player_b,result,report_a,report_b,revision,source,match_id,game_claimed,tournament_id
        FROM tournament_pairings WHERE id=?""", (pairing_id,)).fetchone()
    actor = 0 if row[2] == account["player_id"] else 1 if row[3] == account["player_id"] else -1
    names = []
    for player in row[2:4]:
        if player is None:
            names.append("轮空")
        else:
            name, seed = conn.execute("SELECT p.nickname,m.seed FROM players p JOIN tournament_members m ON m.player_id=p.id WHERE p.id=? AND m.tournament_id=?", (player, row[11])).fetchone()
            names.append(name or f"选手{seed:02d}")
    scores = conn.execute("SELECT score_a,score_b,report_score_a,report_score_b FROM tournament_pairings WHERE id=?", (pairing_id,)).fetchone()
    return {"id": row[0], "table": row[1], "names": names, "actor": actor, "bye": row[3] is None,
            "external_match": conn.execute("SELECT external_match FROM tournament_pairings WHERE id=?", (pairing_id,)).fetchone()[0],
            "scores": list(scores[:2]), "report_scores": [json.loads(v) if v else None for v in scores[2:]],
            "result": row[4], "reports": list(row[5:7]), "revision": row[7], "source": row[8],
            "match_id": row[9] if actor >= 0 else "", "game_active": bool(row[10])}


def settings_input(data):
    format_name, rounds, interval = data.get("format", "swiss"), data.get("swiss_rounds", 0), data.get("round_interval", 0)
    if format_name not in FORMATS:
        raise ValueError("赛程须为瑞士轮或瑞士轮加 2、4、8、16 强淘汰赛")
    if not integer(rounds) or rounds > 16:
        raise ValueError("瑞士轮轮数须为 0–16，0 表示按签到人数自动确定")
    if not integer(interval) or interval > 7 * 86400:
        raise ValueError("自动轮次间隔须为 0–7 天，0 表示手动推进")
    return format_name, int(rounds), int(interval)


def game_format_input(data, default=2):
    value = data.get("game_format", default)
    if not integer(value, 1) or value not in GAME_FORMATS:
        raise ValueError("对局赛制须为 BO1、BO1 换备牌、BO3 或现有娱乐模式")
    return int(value)


def game_mode(game_format):
    return {4: "exploration", 5: "exploration_random"}.get(game_format, "casual")


def start_time_input(value):
    now = int(time.time())
    if not integer(value, 1) or not now < value <= now + 366 * 86400:
        raise ValueError("必须指定未来一年内的具体比赛时间")
    return int(value)


def open_due_checkins(conn, now=None):
    now = int(time.time()) if now is None else now
    with conn:
        conn.execute("UPDATE tournaments SET phase='checkin' WHERE phase='registration' AND start_at>0 AND start_at<=?", (now,))


def seed_roster(conn, tournament_id):
    entrants = [row[0] for row in conn.execute("SELECT player_id FROM tournament_members WHERE tournament_id=? AND in_roster=1", (tournament_id,))]
    secrets.SystemRandom().shuffle(entrants)
    conn.executemany("UPDATE tournament_members SET seed=? WHERE tournament_id=? AND player_id=?",
                     ((index, tournament_id, player) for index, player in enumerate(entrants, 1)))


def start_round(conn, tournament_id, expected_round, now=None):
    if tournament_limitless.bound(conn, tournament_id):
        return tournament_limitless.start_round(conn, tournament_id, expected_round, int(time.time()) if now is None else now)
    if tournament_rules.config(conn, tournament_id)["stages"]:
        return tournament_rules.advance_round(conn, tournament_id, expected_round, now)
    now = int(time.time()) if now is None else now
    row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=?", (tournament_id,)).fetchone()
    settings = config(conn, tournament_id)
    number = settings["round_number"]
    cut = TOP_CUTS.get(settings["format"], 0)
    if number != expected_round:
        raise ValueError("轮次已变化，请刷新后重试")
    if row[4] not in ("locked", "running"):
        raise ValueError("请先结束签到并确定参赛名单")
    if conn.execute("SELECT COUNT(*) FROM tournament_pairings WHERE tournament_id=? AND round_number=? AND result IS NULL",
                    (tournament_id, number)).fetchone()[0]:
        raise ValueError("本轮仍有未结束或待确认对局，请主办方裁定后推进")
    standings = standings_for(conn, tournament_id)
    if number == 0:
        minimum = max(2, cut)
        if not minimum <= len(standings) <= MAX_PLAYERS:
            raise ValueError(f"此赛制需要至少 {minimum} 名已签到选手")
        rounds = settings["swiss_rounds"] or math.ceil(math.log2(len(standings)))
        maximum = len(standings) if len(standings) % 2 else len(standings) - 1
        if rounds > maximum:
            raise ValueError("瑞士轮轮数超过不重复对手与轮空的可用轮数")
        if any(entry["seed"] == 0 for entry in standings):
            seed_roster(conn, tournament_id)
            standings = standings_for(conn, tournament_id)
    else:
        rounds = settings["total_swiss_rounds"]
    if number < rounds:
        stage = "swiss"
        history = conn.execute("SELECT player_a,player_b FROM tournament_pairings WHERE tournament_id=?", (tournament_id,)).fetchall()
        pairs = swiss_pairs(standings, [(a, b) for a, b in history if b is not None], {a for a, b in history if b is None})
    elif cut and number < rounds + cut.bit_length() - 1:
        stage = KNOCKOUT_STAGES[cut >> (number - rounds)]
        if number == rounds:
            pairs = knockout_pairs([entry["player_id"] for entry in standings[:cut]])
        else:
            winners = [(a, b)[result] for a, b, result in conn.execute("""SELECT player_a,player_b,result
                FROM tournament_pairings WHERE tournament_id=? AND round_number=? ORDER BY table_number""", (tournament_id, number))]
            pairs = list(zip(winners[::2], winners[1::2]))
    else:
        conn.execute("UPDATE tournaments SET phase='complete',timer_notice='' WHERE id=?", (tournament_id,))
        tournament_rules.award_rewards(conn, tournament_id, standings)
        return "比赛已结束，最终成绩已确定"
    conn.execute("INSERT INTO tournament_rounds(tournament_id,number,stage,started_at) VALUES(?,?,?,?)", (tournament_id, number + 1, stage, now))
    conn.executemany("""INSERT INTO tournament_pairings(tournament_id,round_number,table_number,player_a,player_b,result,source,match_id)
        VALUES(?,?,?,?,?,?,?,?)""", ((tournament_id, number + 1, table, a, b, 0 if b is None else None,
        "bye" if b is None else "", secrets.token_hex(16)) for table, (a, b) in enumerate(pairs, 1)))
    conn.execute("""UPDATE tournaments SET phase='running',total_swiss_rounds=?,round_number=?,round_stage=?,round_started_at=?,timer_notice=''
        WHERE id=?""", (rounds, number + 1, stage, now, tournament_id))
    return "本轮对阵已自动编排"


def handle_result(conn, data, account, row):
    if tournament_limitless.bound(conn, row[0]):
        return error("此比赛以 Limitless 为准，请先在 Limitless 登记结果，再同步到游戏内")
    pairing_id, result, revision = data.get("pairing_id"), data.get("result"), data.get("revision")
    if not integer(pairing_id, 1) or type(result) not in (int, float) or result not in (-1, 0, 1) or not integer(revision):
        return error("结果表格式无效")
    pairing = conn.execute("""SELECT player_a,player_b,result,report_a,report_b,revision,round_number,game_claimed
        FROM tournament_pairings WHERE id=? AND tournament_id=?""", (int(pairing_id), row[0])).fetchone()
    if pairing is None or pairing[1] is None:
        return error("对阵不存在或为轮空")
    settings = config(conn, row[0])
    if row[4] != "running" or settings["round_number"] != pairing[6]:
        return error("只能登记当前轮次的结果")
    if int(revision) != pairing[5]:
        return error("结果表已变化，请刷新后重新确认")
    if result == -1 and settings["round_stage"] not in ("swiss", "round_robin"):
        return error("淘汰赛必须确定获胜选手")
    owned = can_manage(conn, account, row[1])
    try:
        scores = tournament_rules.score_for_result(conn, row[0], data, int(result))
    except ValueError as exc:
        return error(str(exc))
    if data["action"] == "judge_result":
        if not owned:
            return error("仅主办方可以裁定结果")
        conn.execute("UPDATE tournament_pairings SET result=?,source='organizer',revision=revision+1 WHERE id=?", (int(result), int(pairing_id)))
        conn.execute("UPDATE tournament_pairings SET score_a=?,score_b=? WHERE id=?", (*scores, int(pairing_id)))
        return {"ok": True, "message": "主办方裁定已登记"}
    actor = 0 if pairing[0] == account["player_id"] else 1 if pairing[1] == account["player_id"] else -1
    if actor < 0:
        return error("仅本桌选手可以填写或确认结果表")
    if pairing[2] is not None:
        return error("本桌结果已确定")
    if pairing[7]:
        return error("游戏对局进行中，结果将自动回填；争议请联系主办方裁定")
    other_score = conn.execute("SELECT report_score_b,report_score_a FROM tournament_pairings WHERE id=?", (pairing_id,)).fetchone()[actor]
    matches = pairing[4 - actor] == int(result) and other_score is not None and json.loads(other_score) == scores
    if data["action"] == "confirm_result" and not matches:
        return error("对手的结果表已变化，请刷新后重新确认")
    column = "report_a" if actor == 0 else "report_b"
    conn.execute(f"UPDATE tournament_pairings SET {column}=?,revision=revision+1 WHERE id=?", (int(result), int(pairing_id)))
    score_column = "report_score_a" if actor == 0 else "report_score_b"
    conn.execute(f"UPDATE tournament_pairings SET {score_column}=? WHERE id=?", (json.dumps(scores), pairing_id))
    if matches:
        conn.execute("UPDATE tournament_pairings SET result=?,source='agreement' WHERE id=?", (int(result), int(pairing_id)))
        conn.execute("UPDATE tournament_pairings SET score_a=?,score_b=? WHERE id=?", (*scores, pairing_id))
        return {"ok": True, "message": "双方已确认结果，成绩已登记"}
    return {"ok": True, "message": "结果表已提交，等待对手确认"}


def handle(conn, data, account):
    if not account.get("ok") or not isinstance(data, dict):
        return handle_group(conn, data, account)
    open_due_checkins(conn)
    action = data.get("action")
    if action == "create_limitless":
        if not can_create(account, conn):
            return error("仅赛事管理员可从 Limitless 创建比赛")
        try:
            external = tournament_limitless.tournament_id(data.get("url"))
        except ValueError as exc:
            return error(str(exc))
        existing = conn.execute("""SELECT t.id FROM tournaments t JOIN tournament_limitless l ON l.tournament_id=t.id
            WHERE t.owner_id=? AND l.external_id=? AND t.phase!='deleted'""", (account["player_id"], external)).fetchone()
        if existing:
            row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=?", existing).fetchone()
            return detail(conn, row, account, message="已打开你导入的同一 Limitless 比赛")
        with conn:
            tid = conn.execute("INSERT INTO tournaments(owner_id,title,description,created_at) VALUES(?,'Limitless 赛事（同步中）','',?)", (account["player_id"], int(time.time()))).lastrowid
            conn.execute("""INSERT INTO tournament_limitless(tournament_id,external_id,generation,auto_sync,import_pending)
                VALUES(?,?,?,1,1)""", (tid, external, secrets.token_hex(16)))
        message = tournament_limitless.request_sync(conn, tid)
        row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=?", (tid,)).fetchone()
        return detail(conn, row, account, message="已建立赛事，名称、时间和签表将在同步后填入；" + message)
    if action == "create":
        try:
            format_name, rounds, interval = settings_input(data)
            game_format = game_format_input(data)
            start_at = start_time_input(data.get("start_at"))
            stages = tournament_rules.stages_input(data["stages"]) if "stages" in data else []
            if not stages and game_format == 7 and format_name != "swiss":
                raise ValueError("BO2 淘汰阶段需决胜局制，请使用自定义阶段为淘汰赛指定 BO1/BO3/BO5")
            rewards = tournament_rules.rewards_input(data.get("rewards", tournament_rules.DEFAULT_REWARDS))
            if rewards != tournament_rules.DEFAULT_REWARDS and not community_store.is_super(account, conn):
                raise ValueError("仅超级管理员组可修改赛事铜钱奖励")
        except ValueError as exc:
            return error(str(exc))
        with conn:
            answer = handle_group(conn, data, account)
            if not answer["ok"]:
                return answer
            tournament_id = answer["tournament"]["id"]
            conn.execute("UPDATE tournaments SET format=?,swiss_rounds=?,round_interval=?,game_format=?,start_at=? WHERE id=?", (format_name, rounds, interval, game_format, start_at, tournament_id))
            conn.execute("UPDATE tournaments SET stages_json=?,rewards_json=?,game_format=? WHERE id=?", (json.dumps(stages), json.dumps(rewards), stages[0]["game_format"] if stages else game_format, tournament_id))
        row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=?", (tournament_id,)).fetchone()
        return detail(conn, row, account, message=answer["message"])
    if action in ("list", "join", "leave", "checkin", "open_checkin", "close_checkin"):
        answer = handle_group(conn, data, account)
        if action == "close_checkin" and answer.get("ok"):
            with conn:
                seed_roster(conn, int(data["id"]))
            row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=?", (int(data["id"]),)).fetchone()
            return detail(conn, row, account, message=answer["message"])
        return answer
    tournament_id = data.get("id")
    if not integer(tournament_id, 1):
        return error("比赛编号无效")
    row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=? AND phase!='deleted'", (int(tournament_id),)).fetchone()
    if row is None:
        return {**error("比赛不存在"), "tournament_missing": True}
    if action == "detail":
        values = [data.get(key, 0) for key in ("member_page", "pairing_page", "standing_page", "pairing_round", "external_page", "external_phase", "external_round")]
        if any(not integer(value) for value in values) or not integer(data.get("request_page", 0)) or type(data.get("roster_only", False)) is not bool:
            return error("页码或成员筛选无效")
        if values[3] > config(conn, row[0])["round_number"]:
            return error("所选轮次尚未开始")
        return detail(conn, row, account, int(values[0]), data.get("roster_only", False), pairing_page=int(values[1]), standing_page=int(values[2]), pairing_round=int(values[3]), query=data)
    owned = can_manage(conn, account, row[1])
    if action == "submit_decklist":
        try:
            message = submit_decklist(conn, row[0], account["player_id"], data)
            return detail(conn, row, account, message=message)
        except ValueError as exc:
            return error(str(exc))
    if action in ("report_result", "confirm_result", "judge_result"):
        with conn:
            answer = handle_result(conn, data, account, row)
        if not answer["ok"]:
            return answer
        return detail(conn, row, account, message=answer["message"])
    if not owned:
        return error("仅主办方可以管理比赛")
    if action == "review_limitless_join":
        try:
            with conn:
                message = tournament_limitless.review_join(conn, row[0], account["player_id"], data)
            return detail(conn, row, account, message=message)
        except ValueError as exc:
            return error(str(exc))
    if action in ("link_limitless", "sync_limitless", "unlink_limitless", "map_limitless", "complete_limitless"):
        try:
            if action == "link_limitless":
                message = tournament_limitless.configure(conn, row[0], data)
            elif action == "sync_limitless":
                message = tournament_limitless.request_sync(conn, row[0])
            elif action == "map_limitless":
                message = tournament_limitless.save_players(conn, row[0], data.get("mapping"))
            elif action == "complete_limitless":
                if data.get("finished") is not True:
                    raise ValueError("请先确认 Limitless 已公布最终排名且赛事已结束")
                with conn:
                    message = tournament_limitless.complete(conn, row[0])
            else:
                if config(conn, row[0])["round_number"]:
                    raise ValueError("已开赛 Limitless 比赛不能解除来源绑定")
                if conn.execute("SELECT 1 FROM tournament_limitless_requests WHERE tournament_id=? AND status IN ('pending','approved')", (row[0],)).fetchone():
                    raise ValueError("已有选手申请或通过身份审核，不能解除赛事来源")
                with conn:
                    conn.execute("DELETE FROM tournament_limitless WHERE tournament_id=?", (row[0],))
                    conn.execute("DELETE FROM tournament_limitless_players WHERE tournament_id=?", (row[0],))
                message = "已解除 Limitless 绑定"
        except ValueError as exc:
            return error(str(exc))
        row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=?", (row[0],)).fetchone()
        return detail(conn, row, account, message=message, query={"external_view": "pairings", **data})
    if action == "delete":
        page = data.get("page", 0)
        if not integer(page):
            return error("页码无效")
        with conn:
            conn.execute("""UPDATE rating_matches SET status='cancelled' WHERE status IN ('pending','playing')
                AND match_id IN (SELECT match_id FROM tournament_pairings WHERE tournament_id=?)""", (row[0],))
            for table in ("tournament_decklists", "tournament_decklist_rules", "tournament_schedules", "tournament_pairings", "tournament_rounds", "tournament_members", "tournament_stage_members", "tournament_limitless", "tournament_limitless_players", "tournament_limitless_rounds", "tournament_limitless_requests"):
                conn.execute(f"DELETE FROM {table} WHERE tournament_id=?", (row[0],))
            # Keep an ID tombstone so stale clients cannot act on a newly created competition with the same ID.
            conn.execute("UPDATE tournaments SET phase='deleted',title='',description='',timer_notice='',round_interval=0 WHERE id=?", (row[0],))
        answer = handle_group(conn, {"action": "list", "page": int(page)}, account)
        answer["message"] = "比赛已删除"
        return answer
    try:
        with conn:
            if action == "configure_decklist":
                message = configure_decklist(conn, row[0], data)
            elif action == "configure":
                if tournament_limitless.bound(conn, row[0]):
                    raise ValueError("Limitless 比赛的轮次与局制由来源签表决定")
                format_name, rounds, interval = settings_input(data)
                settings = config(conn, row[0])
                advanced = tournament_rules.config(conn, row[0])
                stages = tournament_rules.stages_input(data["stages"]) if "stages" in data else advanced["stages"]
                if settings["round_number"] > 0 and stages != advanced["stages"]:
                    # Future stages and advancement thresholds may be repaired, but played rules are immutable.
                    index = advanced["stage_index"]
                    if len(stages) <= index or stages[:index] != advanced["stages"][:index] or any(stages[index][key] != advanced["stages"][index][key] for key in ("kind", "game_format", "points", "rounds")):
                        raise ValueError("已开赛阶段的赛制、局制、轮数和计分不可改；可调整晋级条件和后续阶段")
                game_format = game_format_input(data, settings["game_format"])
                if stages:
                    game_format = stages[advanced["stage_index"]]["game_format"]
                elif game_format == 7 and format_name != "swiss":
                    raise ValueError("BO2 不适用于淘汰阶段，请为淘汰阶段指定 BO1/BO3/BO5")
                start_at = settings["start_at"]
                if "start_at" in data and data["start_at"] != start_at:
                    if row[4] != "registration":
                        raise ValueError("到达比赛时间后不能修改比赛时间")
                    start_at = start_time_input(data["start_at"])
                elif "start_at" in data and not integer(data["start_at"], 1):
                    raise ValueError("必须指定具体比赛时间")
                if settings["round_number"] > 0 and (format_name != settings["format"] or rounds != settings["swiss_rounds"] or game_format != settings["game_format"]):
                    raise ValueError("开始比赛后不能修改赛制或瑞士轮轮数")
                if row[4] == "complete":
                    raise ValueError("比赛已结束")
                conn.execute("UPDATE tournaments SET format=?,swiss_rounds=?,round_interval=?,game_format=?,start_at=?,timer_notice='' WHERE id=?", (format_name, rounds, interval, game_format, start_at, row[0]))
                conn.execute("UPDATE tournaments SET stages_json=? WHERE id=?", (json.dumps(stages), row[0]))
                message = "比赛设置已保存"
            elif action == "update_rewards":
                if not community_store.is_super(account, conn):
                    raise ValueError("仅超级管理员组可修改赛事铜钱奖励")
                if tournament_rules.config(conn, row[0])["rewards_paid"]:
                    raise ValueError("赛事奖励已发放，不能追溯修改已入账铜钱")
                rewards = tournament_rules.rewards_input(data.get("rewards"))
                conn.execute("UPDATE tournaments SET rewards_json=? WHERE id=?", (json.dumps(rewards), row[0]))
                message = "赛事铜钱奖励已保存"
            elif action == "update_description":
                description = data.get("description")
                if not isinstance(description, str) or len(description) > 2000:
                    raise ValueError("比赛描述最多 2000 个字符")
                conn.execute("UPDATE tournaments SET description=? WHERE id=?", (description.strip(), row[0]))
                if "title" in data:
                    title = data["title"]
                    if not isinstance(title, str) or not 1 <= len(title.strip()) <= 40:
                        raise ValueError("比赛名称须为 1–40 个字符")
                    conn.execute("UPDATE tournaments SET title=? WHERE id=?", (title.strip(), row[0]))
                message = "比赛描述已保存"
            elif action == "start_round":
                expected = data.get("expected_round")
                if not integer(expected):
                    raise ValueError("轮次参数无效")
                message = start_round(conn, row[0], int(expected))
            elif action == "schedule":
                task, due, expected = data.get("task"), data.get("due_at"), data.get("expected_round")
                if task not in ("open_checkin", "close_checkin", "start_round") or not integer(due, 1) or not integer(expected):
                    raise ValueError("定时任务格式无效")
                if not int(time.time()) < due <= int(time.time()) + 366 * 86400:
                    raise ValueError("定时时间须在未来一年内")
                if row[4] == "complete":
                    raise ValueError("比赛已结束")
                if task in ("open_checkin", "close_checkin") and (row[4] not in ("registration", "checkin") or expected != 0):
                    raise ValueError("此阶段不能再安排签到任务")
                if task == "start_round" and expected != config(conn, row[0])["round_number"]:
                    raise ValueError("只能为下一轮安排定时开始")
                if conn.execute("SELECT COUNT(*) FROM tournament_schedules WHERE tournament_id=? AND status IN ('scheduled','waiting')", (row[0],)).fetchone()[0] >= 20:
                    raise ValueError("请先取消或完成已有定时任务")
                conn.execute("INSERT INTO tournament_schedules(tournament_id,action,due_at,expected_round) VALUES(?,?,?,?)", (row[0], task, int(due), int(expected)))
                message = "定时任务已保存到服务器"
            elif action == "cancel_schedule":
                task_id = data.get("schedule_id")
                if not integer(task_id, 1):
                    raise ValueError("定时任务编号无效")
                cursor = conn.execute("UPDATE tournament_schedules SET status='cancelled' WHERE id=? AND tournament_id=? AND status IN ('scheduled','waiting')", (int(task_id), row[0]))
                if cursor.rowcount == 0:
                    raise ValueError("任务已执行或不存在")
                message = "定时任务已取消"
            else:
                raise ValueError("比赛操作无效")
    except ValueError as exc:
        return error(str(exc))
    row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=?", (row[0],)).fetchone()
    return detail(conn, row, account, message=message)


def tick(conn, now=None):
    """Called by the HTTP server even when no client is connected."""
    now = int(time.time()) if now is None else now
    tournament_limitless.tick(conn, now)
    open_due_checkins(conn, now)
    with conn:
        expired = conn.execute("SELECT id,match_id FROM tournament_pairings WHERE game_claimed=1 AND result IS NULL AND game_heartbeat<?", (now - 90,)).fetchall()
        for pairing_id, match_id in expired:
            conn.execute("UPDATE rating_matches SET status='cancelled' WHERE match_id=? AND status IN ('pending','playing')", (match_id,))
            conn.execute("UPDATE tournament_pairings SET game_claimed=0,match_id=?,revision=revision+1 WHERE id=?", (secrets.token_hex(16), pairing_id))
    tasks = conn.execute("SELECT id,tournament_id,action,expected_round FROM tournament_schedules WHERE status IN ('scheduled','waiting') AND due_at<=? ORDER BY due_at,id LIMIT 100", (now,)).fetchall()
    for task_id, tournament_id, action, expected in tasks:
        row = conn.execute(f"SELECT {SELECT} FROM tournaments WHERE id=?", (tournament_id,)).fetchone()
        settings = config(conn, tournament_id)
        waiting = action == "start_round" and row[4] == "running" and settings["round_number"] == expected and conn.execute("SELECT COUNT(*) FROM tournament_pairings WHERE tournament_id=? AND round_number=? AND result IS NULL", (tournament_id, expected)).fetchone()[0] > 0
        if waiting:
            with conn:
                message = "等待 Limitless 公布本轮赛果并同步" if tournament_limitless.bound(conn, tournament_id) else "到点后仍有未结束对局，等待主办方裁定"
                conn.execute("UPDATE tournament_schedules SET status='waiting',message=? WHERE id=?", (message, task_id))
            continue
        try:
            with conn:
                if action == "start_round":
                    message = start_round(conn, tournament_id, expected, now)
                else:
                    owner = conn.execute("SELECT username FROM players WHERE id=?", (row[1],)).fetchone()
                    account = {"ok": True, "username": owner[0] if owner else "", "player_id": row[1]}
                    answer = handle_group(conn, {"action": action, "id": tournament_id}, account)
                    if not answer["ok"]:
                        raise ValueError(answer["message"])
                    if action == "close_checkin":
                        seed_roster(conn, tournament_id)
                    message = answer["message"]
                conn.execute("UPDATE tournament_schedules SET status='done',message=? WHERE id=?", (message, task_id))
        except ValueError as exc:
            with conn:
                status = "waiting" if action == "start_round" and row[4] in ("locked", "running") and config(conn, tournament_id)["round_number"] == expected and tournament_limitless.bound(conn, tournament_id) else "failed"
                conn.execute("UPDATE tournament_schedules SET status=?,message=? WHERE id=?", (status, str(exc), task_id))
    for tournament_id, number in conn.execute("SELECT id,round_number FROM tournaments WHERE phase='running' AND round_interval>0 AND round_started_at+round_interval<=?", (now,)).fetchall():
        try:
            with conn:
                start_round(conn, tournament_id, number, now)
        except ValueError as exc:
            with conn:
                conn.execute("UPDATE tournaments SET timer_notice=? WHERE id=?", (str(exc), tournament_id))


def handle_game(conn, data):
    """Trusted loopback relay API; never dispatched by the player's endpoint."""
    if isinstance(data, dict) and data.get("action") == "claim" and isinstance(data.get("match_id"), str):
        # Re-read the rules and lists under the same write lock used by submissions/settings.
        with conn:
            conn.execute("UPDATE tournaments SET id=id WHERE id=(SELECT tournament_id FROM tournament_pairings WHERE match_id=?)", (data["match_id"],))
            return _handle_game(conn, data)
    return _handle_game(conn, data)


def _handle_game(conn, data):
    if not isinstance(data, dict) or not isinstance(data.get("match_id"), str):
        return error("比赛对局标识无效")
    row = conn.execute("""SELECT p.id,p.tournament_id,p.round_number,p.player_a,p.player_b,p.result,p.game_claimed,
        t.round_number,t.phase,t.title FROM tournament_pairings p JOIN tournaments t ON t.id=p.tournament_id WHERE p.match_id=?""",
        (data["match_id"],)).fetchone()
    if row is None or row[4] is None:
        return error("比赛对局不存在或为轮空，请刷新比赛页面")
    action = data.get("action")
    active = row[5] is None and row[2] == row[7] and row[8] == "running"
    if action == "status":
        if active and row[6]:
            with conn:
                conn.execute("UPDATE tournament_pairings SET game_heartbeat=? WHERE id=?", (int(time.time()), row[0]))
        return {"ok": True, "closed": not active, "result": row[5]}
    if action in ("lookup", "claim"):
        rule = decklist_rule(conn, row[1], row[2])
        required = rule["fixed_deck"] and config(conn, row[1])["game_format"] not in (4, 5)
        if conn.execute("SELECT source FROM tournament_pairings WHERE id=?", (row[0],)).fetchone()[0] == "awaiting_limitless":
            return error("游戏已结束，请在 Limitless 登记赛果并同步后继续")
        if not active:
            return error("本桌结果已确定或轮次已结束")
        if action == "lookup":
            player = data.get("player_id")
            if type(player) is not int or player not in row[3:5]:
                return error("此对局仅限当前编排的两位选手进入")
            try:
                signature = checked_deck(data.get("deck"), config(conn, row[1])["game_format"])
            except ValueError as exc:
                return error(str(exc))
            if required:
                submitted = conn.execute("SELECT signature FROM tournament_decklists WHERE tournament_id=? AND round_number=? AND player_id=?", (row[1], row[2], player)).fetchone()
                if not submitted:
                    return error("请先提交本轮比赛牌表")
                if submitted[0] != signature:
                    return error("本地卡组与服务器已交付牌表不一致，请恢复提交的卡组")
                if int(time.time()) < rule["deadline_at"]:
                    return error("本轮牌表尚未截止，请在截止后进入比赛")
        else:
            if data.get("players") != list(row[3:5]):
                return error("比赛对局选手与编排不一致")
            expected_mode = game_mode(config(conn, row[1])["game_format"])
            if data.get("mode", expected_mode) != expected_mode:
                return error("比赛对局模式与指定赛制不一致")
            signatures = data.get("deck_signatures")
            if not isinstance(signatures, list) or len(signatures) != 2 or any(not isinstance(s, str) or len(s) != 64 for s in signatures):
                return error("双方尚未通过服务器牌表验证")
            if required:
                if int(time.time()) < rule["deadline_at"]:
                    return error("本轮牌表尚未截止，请在截止后进入比赛")
                for player, signature in zip(row[3:5], signatures):
                    submitted = conn.execute("SELECT signature FROM tournament_decklists WHERE tournament_id=? AND round_number=? AND player_id=?", (row[1], row[2], player)).fetchone()
                    if not submitted or submitted[0] != signature:
                        return error("比赛牌表未提交或已变化，请重新进入")
            with conn:
                conn.execute("UPDATE tournament_pairings SET game_claimed=1,game_heartbeat=?,report_a=NULL,report_b=NULL,revision=revision+1 WHERE id=? AND game_claimed=0",
                             (int(time.time()), row[0]))
        game_format = config(conn, row[1])["game_format"]
        stage = tournament_rules.active_stage(conn, row[1])
        return {"ok": True, "players": list(row[3:5]), "name": row[9], "round_number": row[2],
                **({"deck_signature": signature} if action == "lookup" else {}),
                "game_format": game_format, "mode": game_mode(game_format),
                "requires_scores": game_format in (6, 7) or bool(stage and stage["points"]["scores"])}
    if action == "cancel":
        if row[5] is None:
            with conn:
                conn.execute("UPDATE tournament_pairings SET game_claimed=0,match_id=?,revision=revision+1 WHERE id=?", (secrets.token_hex(16), row[0]))
        return {"ok": True}
    if action == "settle":
        winner = data.get("winner")
        if type(winner) is not int or winner not in (-1, 0, 1):
            return error("比赛对局结果无效")
        stage = tournament_rules.active_stage(conn, row[1])
        if winner == -1 and (stage["kind"] if stage else config(conn, row[1])["round_stage"]) not in ("swiss", "round_robin"):
            return error("此阶段不允许平局")
        try:
            scores = tournament_rules.score_for_result(conn, row[1], data, winner)
        except ValueError as exc:
            return error(str(exc))
        if row[5] is None:
            if not active or not row[6]:
                return error("比赛对局尚未登记或轮次已结束")
            if tournament_limitless.bound(conn, row[1]):
                conn.execute("""UPDATE tournament_pairings SET source='awaiting_limitless',revision=revision+1,
                    game_claimed=0,report_a=?,report_b=?,report_score_a=?,report_score_b=? WHERE id=?""",
                    (winner, winner, json.dumps(scores), json.dumps(scores), row[0]))
            else:
                conn.execute("UPDATE tournament_pairings SET result=?,source='game',revision=revision+1,game_claimed=0 WHERE id=?", (winner, row[0]))
                conn.execute("UPDATE tournament_pairings SET score_a=?,score_b=? WHERE id=?", (*scores, row[0]))
        return {"ok": True, "result": row[5] if row[5] is not None else winner}
    return error("比赛对局操作无效")
