"""Read-only Limitless mirrors. Network workers never touch the account database."""
import json
import re
import secrets
import threading
import time
from datetime import datetime
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

BASE = "https://play.limitlesstcg.com"
INTERVAL = 120
MAX_BYTES = 4 * 1024 * 1024
_jobs = {}
_lock = threading.Lock()


class SyncError(ValueError):
    def __init__(self, message, retry_after=INTERVAL):
        super().__init__(message)
        self.retry_after = max(INTERVAL, min(3600, retry_after))


class LiveTournament(SyncError):
    pass


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def initialize(conn):
    if "external_match" not in {r[1] for r in conn.execute("PRAGMA table_info(tournament_pairings)")}:
        conn.execute("ALTER TABLE tournament_pairings ADD COLUMN external_match TEXT NOT NULL DEFAULT ''")
    conn.execute("""CREATE TABLE IF NOT EXISTS tournament_limitless (
        tournament_id INTEGER PRIMARY KEY, external_id TEXT NOT NULL, generation TEXT NOT NULL,
        auto_sync INTEGER NOT NULL DEFAULT 0, snapshot_json TEXT NOT NULL DEFAULT '{}',
        synced_at INTEGER NOT NULL DEFAULT 0, attempted_at INTEGER NOT NULL DEFAULT 0,
        retry_at INTEGER NOT NULL DEFAULT 0, error TEXT NOT NULL DEFAULT '')""")
    conn.execute("""CREATE TABLE IF NOT EXISTS tournament_limitless_players (
        tournament_id INTEGER, external_player TEXT, player_id INTEGER,
        PRIMARY KEY(tournament_id,external_player), UNIQUE(tournament_id,player_id))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS tournament_limitless_rounds (
        tournament_id INTEGER, round_number INTEGER, phase INTEGER, external_round INTEGER,
        PRIMARY KEY(tournament_id,round_number))""")
    columns = {r[1] for r in conn.execute("PRAGMA table_info(tournament_limitless)")}
    if "import_pending" not in columns:
        conn.execute("ALTER TABLE tournament_limitless ADD COLUMN import_pending INTEGER NOT NULL DEFAULT 0")
    conn.execute("""CREATE TABLE IF NOT EXISTS tournament_limitless_requests (
        tournament_id INTEGER NOT NULL, player_id INTEGER NOT NULL, external_player TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending', revision INTEGER NOT NULL DEFAULT 1,
        submitted_at INTEGER NOT NULL, reviewed_at INTEGER, reviewer_id INTEGER,
        PRIMARY KEY(tournament_id,player_id))""")


def tournament_id(value):
    if not isinstance(value, str) or len(value) > 500:
        raise ValueError("请填写 Limitless 赛事链接或 24 位赛事编号")
    value = value.strip()
    if re.fullmatch(r"[a-fA-F0-9]{24}", value):
        return value.lower()
    try:
        url = urlsplit(value)
        if (url.scheme != "https" or url.netloc != "play.limitlesstcg.com"
                or not re.fullmatch(r"/tournament/[a-fA-F0-9]{24}(?:/(?:pairings|standings|details))?/?", url.path)):
            raise ValueError
        return url.path.split("/")[2].lower()
    except ValueError:
        raise ValueError("仅支持 https://play.limitlesstcg.com/tournament/… 的赛事链接") from None


def _fetch(external_id, endpoint):
    request = Request(f"{BASE}/api/tournaments/{external_id}/{endpoint}",
                      headers={"Accept": "application/json", "User-Agent": "Multicolor-Arena/Limitless-Sync"})
    try:
        with build_opener(NoRedirect()).open(request, timeout=5) as response:
            body = response.read(MAX_BYTES + 1)
        if len(body) > MAX_BYTES:
            raise SyncError("Limitless 数据过大，未替换已有签表")
        return json.loads(body)
    except HTTPError as exc:
        if exc.code == 400 and b"Tournament is not finished yet" in exc.read(1024):
            raise LiveTournament("赛事尚未结束，读取公开网页") from None
        if exc.code == 429:
            delay = exc.headers.get("Retry-After", "120")
            raise SyncError("Limitless 请求限流，将稍后重试", int(delay) if delay.isdigit() else INTERVAL) from None
        if exc.code == 404:
            raise SyncError("Limitless 赛事不存在，或尚未公开 API 数据") from None
        raise SyncError(f"Limitless 返回 HTTP {exc.code}，保留上次签表") from None
    except (URLError, TimeoutError, OSError):
        raise SyncError("无法连接 Limitless，保留上次签表并稍后重试") from None
    except (ValueError, UnicodeError):
        raise SyncError("Limitless 返回的数据格式无效，保留上次签表") from None


def _number(value, default=0):
    if value is None:
        return default
    if type(value) is not int or not 0 <= value <= 100000:
        raise SyncError("Limitless 数据中的轮次或成绩无效")
    return value


def _text(value, limit=100):
    if not isinstance(value, str) or len(value) > limit:
        raise SyncError("Limitless 数据中的选手或名称无效")
    return value


def snapshot(external_id):
    try:
        details = _fetch(external_id, "details")
    except LiveTournament:
        import tournament_limitless_web
        try:
            details, standings, pairings = tournament_limitless_web.fetch(external_id)
        except ValueError as exc:
            raise SyncError(str(exc)) from None
    else:
        standings = _fetch(external_id, "standings")
        pairings = _fetch(external_id, "pairings")
    return normalize_snapshot(details, standings, pairings)


def normalize_snapshot(details, standings, pairings):
    if (not isinstance(details, dict) or not isinstance(standings, list) or len(standings) > 4096
            or not isinstance(pairings, list) or len(pairings) > 20000):
        raise SyncError("Limitless 数据格式或规模不受支持")
    names, players, matches = {}, [], []
    for entry in standings:
        if not isinstance(entry, dict) or not isinstance(entry.get("record", {}), dict):
            raise SyncError("Limitless 排名数据无效")
        player = _text(entry.get("player"))
        if not player or player in names:
            raise SyncError("Limitless 选手编号缺失或重复")
        name = _text(entry.get("name") or player, 160)
        names[player] = name
        record = entry.get("record", {})
        players.append({"player": player, "name": name, "placing": _number(entry.get("placing")),
                        "wins": _number(record.get("wins")), "losses": _number(record.get("losses")),
                        "ties": _number(record.get("ties")), "drop": entry.get("drop") is not None,
                        "drop_round": _number(entry.get("drop"))})
    seen = set()
    for entry in pairings:
        if not isinstance(entry, dict):
            raise SyncError("Limitless 对阵数据无效")
        a, b = _text(entry.get("player1")), _text(entry.get("player2") or "")
        if not a or a == b:
            raise SyncError("Limitless 对阵选手无效")
        phase, number = _number(entry.get("phase"), 1), _number(entry.get("round"), 1)
        table, label = _number(entry.get("table")), _text(entry.get("match") or "")
        location = ("match", label) if label else ("table", table) if table else ("players", a, b)
        key = (phase, number, location)
        if key in seen:
            raise SyncError("Limitless 对阵位置重复，未替换已有签表")
        seen.add(key)
        winner = entry.get("winner")
        if winner is None:
            result = "pending"
        elif type(winner) is int and winner in (0, -1):
            result = "tie" if winner == 0 else "double_loss" if b else "auto_loss"
        elif isinstance(winner, str) and winner in (a, b) and winner:
            result = "bye" if not b else "a" if winner == a else "b"
        else:
            raise SyncError("Limitless 胜负数据无效，未替换已有签表")
        matches.append({"phase": phase, "round": number, "table": table, "match": label,
                        "players": [a, b], "names": [names.get(a, a), names.get(b, b)], "result": result})
    rounds = sorted({(m["phase"], m["round"]) for m in matches})
    if len(rounds) > 256:
        raise SyncError("Limitless 赛事轮次过多")
    phases = details.get("phases", [])
    if not isinstance(phases, list) or len(phases) > 32 or any(not isinstance(p, dict) for p in phases):
        raise SyncError("Limitless 阶段数据无效")
    normalized_phases = [{"phase": _number(p.get("phase"), i + 1), "type": _text(p.get("type", "")),
                          "mode": _text(p.get("mode", "")), "rounds": _number(p.get("rounds"))} for i, p in enumerate(phases)]
    for phase in normalized_phases:
        if phase["type"] != "SINGLE_BRACKET":
            continue
        bracket = [m for m in matches if m["phase"] == phase["phase"]]
        for match in bracket:
            label = re.fullmatch(r"T(\d+)-(\d+)", match["match"])
            if not label or int(label[1]) < 2 or int(label[1]) & (int(label[1]) - 1):
                raise SyncError("Limitless 单败签位标签未知，不能推测晋级轮次")
            match["bracket_size"], match["bracket_table"] = int(label[1]), int(label[2])
        largest = max((m["bracket_size"] for m in bracket), default=2)
        for match in bracket:
            match["source_round"] = match["round"]
            match["round"] = largest.bit_length() - match["bracket_size"].bit_length() + 1
    start_at = 0
    if details.get("date"):
        try:
            date = datetime.fromisoformat(details["date"].replace("Z", "+00:00"))
            if date.tzinfo is None:
                raise ValueError
            start_at = int(date.timestamp())
        except (ValueError, TypeError, AttributeError, OverflowError):
            raise SyncError("Limitless 比赛时间无效") from None
    return {"title": _text(details.get("name"), 300), "start_at": start_at,
            "description": _text(details.get("description", ""), 2000),
            "started": bool(pairings) or details.get("started") is True,
            "finished": details.get("finished", True),
            "phases": normalized_phases,
            "standings": sorted(players, key=lambda p: (p["placing"] or 100001, p["player"])),
            "pairings": sorted(matches, key=lambda m: (m["phase"], m["round"], m["table"], m.get("bracket_table", 0), m["match"], m["players"]))}


def _scope(conn):
    return conn.execute("PRAGMA database_list").fetchone()[2] or str(id(conn))


def _worker(key, external_id):
    try:
        result = (snapshot(external_id), "", INTERVAL)
    except SyncError as exc:
        result = (None, str(exc), exc.retry_after)
    except Exception:
        result = (None, "Limitless 同步失败，保留上次签表", INTERVAL)
    with _lock:
        _jobs[key] = result


def request_sync(conn, tid, now=None):
    now = int(time.time()) if now is None else now
    if conn.execute("SELECT phase FROM tournaments WHERE id=?", (tid,)).fetchone()[0] == "complete":
        raise ValueError("比赛已按来源排名结算，签表已封存")
    row = conn.execute("SELECT external_id,generation,retry_at FROM tournament_limitless WHERE tournament_id=?", (tid,)).fetchone()
    if row is None:
        raise ValueError("请先绑定 Limitless 赛事")
    key = (_scope(conn), tid, row[1])
    with _lock:
        if key in _jobs:
            return "Limitless 正在同步，请稍后刷新"
        if now < row[2]:
            return f"请在 {row[2] - now} 秒后再次同步"
        if len(_jobs) >= 2:
            return "同步队列繁忙，请稍后重试"
        _jobs[key] = None
    with conn:
        conn.execute("UPDATE tournament_limitless SET attempted_at=?,retry_at=? WHERE tournament_id=?", (now, now + INTERVAL, tid))
    threading.Thread(target=_worker, args=(key, row[0]), daemon=True).start()
    return "已开始同步 Limitless 签表、赛果与排名"


def tick(conn, now=None):
    now = int(time.time()) if now is None else now
    scope = _scope(conn)
    with _lock:
        finished = [(key, _jobs.pop(key)) for key in list(_jobs) if key[0] == scope and _jobs[key] is not None]
    with conn:
        for (_, tid, generation), (data, message, delay) in finished:
            if data is None:
                conn.execute("UPDATE tournament_limitless SET error=?,retry_at=? WHERE tournament_id=? AND generation=?", (message, now + delay, tid, generation))
            else:
                if conn.execute("SELECT 1 FROM tournament_limitless WHERE tournament_id=? AND generation=?", (tid, generation)).fetchone():
                    try:
                        # Validate every imported round before changing either the mirror or local results.
                        updates = result_updates(conn, tid, data)
                    except ValueError as exc:
                        conn.execute("UPDATE tournament_limitless SET error=?,retry_at=? WHERE tournament_id=?", (str(exc), now + delay, tid))
                        continue
                    conn.execute("""UPDATE tournament_limitless SET snapshot_json=?,synced_at=?,retry_at=?,error=''
                        WHERE tournament_id=? AND generation=?""", (json.dumps(data, ensure_ascii=False), now, now + delay, tid, generation))
                    apply_results(conn, updates)
                    if conn.execute("SELECT import_pending FROM tournament_limitless WHERE tournament_id=?", (tid,)).fetchone()[0]:
                        mode = {"BO1": 1, "BO3": 3, "BO5": 6, "BO2": 7}.get(next(iter(data.get("phases", [])), {}).get("mode"), 2)
                        conn.execute("""UPDATE tournaments SET title=?,description=?,start_at=?,game_format=?,phase=? WHERE id=?""",
                                     (data["title"][:40], data.get("description", ""), data.get("start_at", 0), mode,
                                      "checkin" if source_started(data, now) else "registration", tid))
                        conn.execute("UPDATE tournament_limitless SET import_pending=0 WHERE tournament_id=?", (tid,))
    due = conn.execute("""SELECT l.tournament_id FROM tournament_limitless l JOIN tournaments t ON t.id=l.tournament_id
        WHERE l.auto_sync=1 AND l.retry_at<=? AND t.phase NOT IN ('deleted','complete') ORDER BY l.retry_at LIMIT 2""", (now,)).fetchall()
    for (tid,) in due:
        request_sync(conn, tid, now)


def configure(conn, tid, data):
    external_id = tournament_id(data.get("url"))
    automatic = data.get("auto_sync", False)
    if type(automatic) is not bool:
        raise ValueError("自动同步选项无效")
    if conn.execute("SELECT phase FROM tournaments WHERE id=?", (tid,)).fetchone()[0] == "complete":
        raise ValueError("已结束比赛不能绑定或更换签表来源")
    existing = conn.execute("SELECT external_id FROM tournament_limitless WHERE tournament_id=?", (tid,)).fetchone()
    number = conn.execute("SELECT round_number FROM tournaments WHERE id=?", (tid,)).fetchone()[0]
    if number and (not existing or existing[0] != external_id):
        raise ValueError("已开赛比赛不能改绑 Limitless 来源，请新建比赛")
    with conn:
        if existing and existing[0] == external_id:
            conn.execute("UPDATE tournament_limitless SET auto_sync=? WHERE tournament_id=?", (automatic, tid))
        else:
            if conn.execute("SELECT 1 FROM tournament_limitless_requests WHERE tournament_id=? AND status IN ('pending','approved')", (tid,)).fetchone():
                raise ValueError("已有选手申请或通过身份审核，不能更换赛事来源")
            conn.execute("DELETE FROM tournament_limitless_players WHERE tournament_id=?", (tid,))
            conn.execute("INSERT OR REPLACE INTO tournament_limitless(tournament_id,external_id,generation,auto_sync) VALUES(?,?,?,?)",
                         (tid, external_id, secrets.token_hex(16), automatic))
    return request_sync(conn, tid)


def bound(conn, tid):
    return conn.execute("SELECT 1 FROM tournament_limitless WHERE tournament_id=?", (tid,)).fetchone() is not None


def source_started(data, now=None):
    now = int(time.time()) if now is None else now
    return bool(data.get("started") or data.get("pairings") or 0 < data.get("start_at", 0) <= now)


def known_players(data):
    return {p["player"].casefold(): p["player"] for p in data.get("standings", [])} | {
        p.casefold(): p for m in data.get("pairings", []) for p in m["players"] if p}


def update_account(conn, pid, value):
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_-]{0,32}", value.strip()):
        raise ValueError("Limitless 账号 ID 须为最多 32 位英文字母、数字、下划线或短横线；留空可清除")
    value = value.strip().lower()
    current = conn.execute("SELECT limitless_id FROM players WHERE id=?", (pid,)).fetchone()[0]
    if current != value and conn.execute("""SELECT 1 FROM tournament_limitless_requests r JOIN tournaments t ON t.id=r.tournament_id
            WHERE r.player_id=? AND r.status IN ('pending','approved') AND t.phase NOT IN ('deleted','complete')""", (pid,)).fetchone():
        raise ValueError("有待审核或已通过审核的未结束赛事，暂不能更换 Limitless 账号 ID；待审核申请可先撤回")
    conn.execute("UPDATE players SET limitless_id=? WHERE id=?", (value, pid))
    return value


def admission(conn, tid, pid):
    row = conn.execute("SELECT snapshot_json,synced_at,error FROM tournament_limitless WHERE tournament_id=?", (tid,)).fetchone()
    if row is None:
        return {}
    data = json.loads(row[0])
    phase = conn.execute("SELECT phase FROM tournaments WHERE id=?", (tid,)).fetchone()[0]
    account_id = conn.execute("SELECT limitless_id FROM players WHERE id=?", (pid,)).fetchone()[0]
    application = conn.execute("SELECT external_player,status,revision FROM tournament_limitless_requests WHERE tournament_id=? AND player_id=?", (tid, pid)).fetchone()
    started = source_started(data) or phase in ("locked", "running")
    reason = ""
    external = known_players(data).get(account_id.casefold(), "")
    if phase in ("deleted", "complete"):
        reason = "比赛已结束"
    elif not row[1] or row[2] or int(time.time()) - row[1] > 300:
        reason = "请等待主办方同步最新 Limitless 赛事数据后再加入"
    elif started and not account_id:
        reason = "请先在玩家账号中填写自己的 Limitless 账号 ID"
    elif started and not external:
        reason = "你的 Limitless 账号 ID 不在此赛事的公开选手名单中"
    elif application and application[1] == "pending":
        reason = "加入申请待赛事管理员核验"
    elif started and conn.execute("SELECT 1 FROM tournament_limitless_players WHERE tournament_id=? AND external_player=? AND player_id!=?", (tid, external, pid)).fetchone():
        reason = "该 Limitless 选手已对应其他游戏账号，请联系赛事管理员"
    return {"started": started, "can_join": not reason, "reason": reason, "account_id": account_id,
            "external_player": external, "status": application[1] if application else "",
            "revision": application[2] if application else 0}


def apply_join(conn, tid, pid):
    state = admission(conn, tid, pid)
    if conn.execute("SELECT phase FROM tournaments WHERE id=?", (tid,)).fetchone()[0] in ("complete", "deleted"):
        raise ValueError("比赛已结束，不能申请加入")
    if state.get("status") == "pending":
        return "加入申请已提交，请等待赛事管理员核验"
    if not state.get("can_join"):
        raise ValueError(state.get("reason", "赛事未绑定 Limitless"))
    if conn.execute("SELECT 1 FROM tournament_members WHERE tournament_id=? AND player_id=?", (tid, pid)).fetchone():
        return "你已加入比赛"
    if conn.execute("SELECT COUNT(*) FROM tournament_limitless_requests WHERE tournament_id=? AND status='pending'", (tid,)).fetchone()[0] >= 256:
        raise ValueError("待审核申请过多，请联系赛事管理员")
    conn.execute("""INSERT INTO tournament_limitless_requests(tournament_id,player_id,external_player,submitted_at)
        VALUES(?,?,?,?) ON CONFLICT(tournament_id,player_id) DO UPDATE SET external_player=excluded.external_player,
        status='pending',revision=revision+1,submitted_at=excluded.submitted_at,reviewed_at=NULL,reviewer_id=NULL""",
                 (tid, pid, state["external_player"], int(time.time())))
    return "加入申请已提交，管理员确认你是真实比赛选手后才会纳入参赛名单"


def review_join(conn, tid, reviewer, payload):
    pid, revision, approve = payload.get("player_id"), payload.get("revision"), payload.get("approve")
    if (type(pid) not in (int, float) or not 1 <= pid <= 2**53 - 1 or int(pid) != pid
            or type(revision) not in (int, float) or not 1 <= revision <= 2**53 - 1 or int(revision) != revision or type(approve) is not bool):
        raise ValueError("审核参数无效")
    row = conn.execute("SELECT external_player,status,revision FROM tournament_limitless_requests WHERE tournament_id=? AND player_id=?", (tid, pid)).fetchone()
    if not row or row[1] != "pending" or row[2] != revision:
        raise ValueError("申请状态已变化，请刷新后重新审核")
    phase = conn.execute("SELECT phase FROM tournaments WHERE id=?", (tid,)).fetchone()[0]
    if phase in ("complete", "deleted"):
        raise ValueError("比赛已结束，不能审核加入")
    if approve:
        data = read_snapshot(conn, tid)
        account_id = conn.execute("SELECT limitless_id FROM players WHERE id=?", (pid,)).fetchone()[0]
        if account_id.casefold() != row[0].casefold() or known_players(data).get(account_id.casefold()) != row[0]:
            raise ValueError("申请账号已变化或不在最新赛事选手名单中，请拒绝后重新申请")
        conflict = conn.execute("SELECT external_player,player_id FROM tournament_limitless_players WHERE tournament_id=? AND (external_player=? OR player_id=?)", (tid, row[0], pid)).fetchall()
        if any(external != row[0] or player != pid for external, player in conflict):
            raise ValueError("选手账号对应关系冲突，不能重复批准")
        if conn.execute("SELECT COUNT(*) FROM tournament_members WHERE tournament_id=?", (tid,)).fetchone()[0] >= 128:
            raise ValueError("比赛群组最多 128 人")
        now = int(time.time())
        conn.execute("INSERT OR IGNORE INTO tournament_limitless_players VALUES(?,?,?)", (tid, row[0], pid))
        seed = conn.execute("SELECT COALESCE(MAX(seed),0)+1 FROM tournament_members WHERE tournament_id=?", (tid,)).fetchone()[0]
        conn.execute("""INSERT INTO tournament_members(tournament_id,player_id,joined_at,checked_in_at,in_roster,seed)
            VALUES(?,?,?,?,1,?)""", (tid, pid, now, now, seed))
    conn.execute("""UPDATE tournament_limitless_requests SET status=?,reviewed_at=?,reviewer_id=?
        WHERE tournament_id=? AND player_id=?""", ("approved" if approve else "rejected", int(time.time()), reviewer, tid, pid))
    return "已核验并纳入参赛名单" if approve else "已拒绝加入申请"


def requests_view(conn, tid, page=0):
    count = conn.execute("SELECT COUNT(*) FROM tournament_limitless_requests WHERE tournament_id=? AND status='pending'", (tid,)).fetchone()[0]
    pages = max(1, (count + 19) // 20)
    page = min(page, pages - 1)
    rows = conn.execute("""SELECT r.player_id,p.username,p.nickname,r.external_player,r.revision FROM tournament_limitless_requests r
        JOIN players p ON p.id=r.player_id WHERE r.tournament_id=? AND r.status='pending'
        ORDER BY r.submitted_at,r.player_id LIMIT 20 OFFSET ?""", (tid, page * 20)).fetchall()
    return {"entries": [dict(zip(("player_id", "username", "nickname", "external_player", "revision"), r)) for r in rows],
            "page": page, "pages": pages, "total": count}


def read_snapshot(conn, tid, now=None):
    row = conn.execute("SELECT snapshot_json,synced_at,error FROM tournament_limitless WHERE tournament_id=?", (tid,)).fetchone()
    if not row or not row[1]:
        raise ValueError("请先成功同步 Limitless 签表，再开启轮次")
    if row[2]:
        raise ValueError("Limitless 同步异常，请成功同步后再推进：" + row[2])
    if (int(time.time()) if now is None else now) - row[1] > 300:
        raise ValueError("Limitless 签表已超过 5 分钟，请先同步最新签表")
    return json.loads(row[0])


def save_players(conn, tid, text):
    if conn.execute("SELECT round_number FROM tournaments WHERE id=?", (tid,)).fetchone()[0]:
        raise ValueError("开赛后不能更换选手账号对应关系")
    if not isinstance(text, str) or len(text) > 12000:
        raise ValueError("账号对应表格式无效")
    data = read_snapshot(conn, tid)
    known = {p["player"] for p in data["standings"]} | {p for m in data["pairings"] for p in m["players"] if p}
    pairs, seen, local = [], set(), set()
    for line in text.splitlines():
        if not line.strip():
            continue
        parts = line.strip().split("=")
        if len(parts) != 2:
            raise ValueError("每行请填写 Limitless用户名=游戏账号")
        external, username = (p.strip() for p in parts)
        player = conn.execute("SELECT id FROM players WHERE username=? COLLATE NOCASE", (username,)).fetchone()
        if external not in known or not player or external in seen or player[0] in local:
            raise ValueError(f"账号不存在、重复或不在来源签表中：{external}={username}")
        pairs.append((tid, external, player[0])); seen.add(external); local.add(player[0])
    if len(pairs) > 128:
        raise ValueError("游戏内比赛最多支持 128 位选手")
    proposed = {player: external for _, external, player in pairs}
    for player, external in conn.execute("SELECT player_id,external_player FROM tournament_limitless_requests WHERE tournament_id=? AND status='approved'", (tid,)):
        if proposed.get(player) != external:
            raise ValueError("已审核选手的账号对应关系不能更换或移除")
    with conn:
        conn.execute("DELETE FROM tournament_limitless_players WHERE tournament_id=?", (tid,))
        conn.executemany("INSERT INTO tournament_limitless_players VALUES(?,?,?)", pairs)
    return "选手账号对应关系已保存"


def _mapped(conn, tid):
    return dict(conn.execute("SELECT external_player,player_id FROM tournament_limitless_players WHERE tournament_id=?", (tid,)))


def _matches(data, phase, number):
    return [m for m in data["pairings"] if (m["phase"], m["round"]) == (phase, number)]


def _result(match):
    return {"pending": None, "a": 0, "b": 1, "bye": 0, "tie": -1, "double_loss": -2, "auto_loss": -2}[match["result"]]


def result_updates(conn, tid, data):
    mapping = _mapped(conn, tid)
    updates = []
    for number, phase, external_round in conn.execute("SELECT round_number,phase,external_round FROM tournament_limitless_rounds WHERE tournament_id=?", (tid,)):
        source = _matches(data, phase, external_round)
        local = conn.execute("SELECT id,player_a,player_b,result,table_number,external_match FROM tournament_pairings WHERE tournament_id=? AND round_number=? ORDER BY table_number", (tid, number)).fetchall()
        if len(source) != len(local) or any((mapping.get(m["players"][0]), mapping.get(m["players"][1])) != (p[1], p[2]) or m["table"] and m["table"] != p[4] or m["match"] != p[5] for m, p in zip(source, local)):
            raise ValueError(f"Limitless 第 {phase} 阶段第 {external_round} 轮签表已更改；已开轮次不可自动重排，请核对来源")
        for match, pairing in zip(source, local):
            if pairing[3] != _result(match):
                updates.append((pairing[0], _result(match)))
    return updates


def apply_results(conn, updates):
    for pairing_id, result in updates:
        conn.execute("""UPDATE rating_matches SET status='cancelled' WHERE status IN ('pending','playing')
            AND match_id=(SELECT match_id FROM tournament_pairings WHERE id=?)""", (pairing_id,))
        conn.execute("""UPDATE tournament_pairings SET result=?,source='limitless',game_claimed=0,
            revision=revision+1,score_a=NULL,score_b=NULL WHERE id=?""", (result, pairing_id))


def local_standings(conn, tid):
    row = conn.execute("SELECT snapshot_json FROM tournament_limitless WHERE tournament_id=?", (tid,)).fetchone()
    data = json.loads(row[0])
    mapping = _mapped(conn, tid)
    return [{"player_id": mapping[p["player"]], "nickname": p["name"], "rank": p["placing"],
             "placement": p["placing"], "wins": p["wins"], "draws": p["ties"], "losses": p["losses"],
             "points": 0, "buchholz": 0, "byes": 0, "source": "limitless"}
            for p in data.get("standings", []) if p["player"] in mapping]


def complete(conn, tid):
    data = read_snapshot(conn, tid)
    if data.get("finished") is False:
        raise ValueError("Limitless 赛事仍在进行中，不能按当前排名结算")
    number, phase = conn.execute("SELECT round_number,phase FROM tournaments WHERE id=?", (tid,)).fetchone()
    if phase != "running" or not number:
        raise ValueError("请先按 Limitless 签表开始并完成比赛")
    rounds = {(m["phase"], m["round"]) for m in data["pairings"]}
    imported = set(conn.execute("SELECT phase,external_round FROM tournament_limitless_rounds WHERE tournament_id=?", (tid,)))
    if rounds != imported or any(m["result"] == "pending" for m in data["pairings"]):
        raise ValueError("Limitless 尚有未导入轮次或未公布赛果，不能结束比赛")
    for stage in data["phases"]:
        phase_matches = [m for m in data["pairings"] if m["phase"] == stage["phase"]]
        if not phase_matches:
            raise ValueError("Limitless 尚有未公布签表的阶段，不能提前结束比赛")
        if stage["type"] == "SINGLE_BRACKET" and not any(m["match"] == "T2-1" for m in phase_matches):
            raise ValueError("Limitless 决赛签表与结果尚未公布，不能结束比赛")
        if stage["type"] not in ("SINGLE_BRACKET", "DOUBLE_BRACKET") and stage.get("rounds", 0) > sum(p == stage["phase"] for p, _ in imported):
            raise ValueError("Limitless 仍缺少计划轮次，不能提前结束比赛")
    mapping = _mapped(conn, tid)
    if not data["standings"] or any(not p["placing"] or p["player"] not in mapping for p in data["standings"]):
        raise ValueError("Limitless 最终排名未公布或选手账号对应关系不完整")
    apply_results(conn, result_updates(conn, tid, data))
    conn.execute("UPDATE tournaments SET phase='complete',timer_notice='' WHERE id=?", (tid,))
    # External placements are used directly; local stage calculations must not override them.
    import tournament_rules
    conn.execute("UPDATE tournaments SET stages_json='[]' WHERE id=?", (tid,))
    tournament_rules.award_rewards(conn, tid, local_standings(conn, tid))
    return "已按 Limitless 最终排名结束比赛并发放奖励"


def start_round(conn, tid, expected, now):
    number, phase = conn.execute("SELECT round_number,phase FROM tournaments WHERE id=?", (tid,)).fetchone()
    if number != expected or phase not in ("locked", "running"):
        raise ValueError("轮次或比赛状态已变化，请先完成签到并刷新")
    data = read_snapshot(conn, tid, now)
    mapping = _mapped(conn, tid)
    if len(data["standings"]) > 128:
        raise ValueError("来源赛事超过 128 人，当前可同步展示签表，但不能导入游戏内开轮")
    rounds = sorted({(m["phase"], m["round"]) for m in data["pairings"]})
    imported = conn.execute("SELECT phase,external_round FROM tournament_limitless_rounds WHERE tournament_id=? ORDER BY round_number", (tid,)).fetchall()
    if rounds[:len(imported)] != imported:
        raise ValueError("Limitless 历轮签表不完整或顺序发生变化，不能推进")
    if imported and any(m["result"] == "pending" for m in _matches(data, *imported[-1])):
        raise ValueError("Limitless 本轮仍有未公布结果，须先在 Limitless 完成登记并同步")
    if len(rounds) <= len(imported):
        raise ValueError("Limitless 尚未公布下一轮签表，游戏内不能自行编排")
    current = rounds[len(imported)]
    matches = _matches(data, *current)
    settings = next((p for p in data["phases"] if p["phase"] == current[0]), None)
    if settings and settings["type"] == "DOUBLE_BRACKET":
        raise ValueError("实时双败树目前仅支持查看，不能导入游戏内开轮")
    if not imported and data["phases"] and current[0] != data["phases"][0]["phase"]:
        raise ValueError("Limitless 首阶段签表缺失，不能从后续阶段开始")
    if current[0] == (imported[-1][0] if imported else current[0]) and current[1] != (imported[-1][1] + 1 if imported else 1):
        raise ValueError("Limitless 历轮签表缺失，不能跳轮分配")
    if imported and current[0] != imported[-1][0]:
        previous_phase = next((p for p in data["phases"] if p["phase"] == imported[-1][0]), {})
        expected_count = previous_phase.get("rounds", 0)
        if previous_phase.get("type") in ("SWISS", "SINGLE_ELIMINATION", "SINGLE_ELIM") and sum(p == imported[-1][0] for p, _ in imported) < expected_count:
            raise ValueError("Limitless 上一阶段仍缺少计划轮次，不能跳阶段分配")
    participants = [p for m in matches for p in m["players"] if p]
    if len(set(participants)) != len(participants):
        raise ValueError("Limitless 同轮有选手重复出场，无法分配；实时淘汰树请等待独立轮次签表")
    missing = [p for p in participants if p not in mapping]
    if number == 0:
        missing = sorted(({p["player"] for p in data["standings"]} | {p for m in data["pairings"] for p in m["players"] if p}) - mapping.keys())
    if missing:
        raise ValueError("请先设置选手游戏账号对应关系：" + "、".join(missing[:6]))
    roster = {p[0] for p in conn.execute("SELECT player_id FROM tournament_members WHERE tournament_id=? AND in_roster=1", (tid,))}
    if not all(mapping[p] in roster for p in participants):
        raise ValueError("Limitless 签表中的选手须先报名、签到并进入游戏内参赛名单")
    mode = {"BO1": 1, "BO3": 3, "BO5": 6, "BO2": 7}.get(settings["mode"] if settings else "")
    if mode is None:
        raise ValueError("Limitless 阶段局制未知，不能猜测对局规则")
    if any(m.get("bracket_size", 0) and len(matches) != m["bracket_size"] // 2 for m in matches):
        raise ValueError("Limitless 此轮实时淘汰签表尚未全部公布，请稍后同步")
    if settings["type"] in ("SWISS", "ROUND_ROBIN"):
        phase_matches = [m for m in data["pairings"] if m["phase"] == current[0]]
        first_round = min(m["round"] for m in phase_matches)
        entrants = ({p["player"] for p in data["standings"]} if current[0] == data["phases"][0]["phase"]
                    else {p for m in phase_matches if m["round"] == first_round for p in m["players"] if p})
        dropped = {p["player"] for p in data["standings"] if p.get("drop_round", 0) and p["drop_round"] < current[1]}
        if set(participants) != entrants - dropped:
            raise ValueError("Limitless 此轮签表未覆盖全部在赛选手，不能分配不完整轮次")
    kind = "swiss" if "SWISS" in settings["type"] else "round_robin" if "ROUND_ROBIN" in settings["type"] else "single_elimination"
    apply_results(conn, result_updates(conn, tid, data))
    conn.execute("INSERT INTO tournament_limitless_rounds VALUES(?,?,?,?)", (tid, number + 1, *current))
    conn.execute("INSERT INTO tournament_rounds(tournament_id,number,stage,started_at,stage_round) VALUES(?,?,?,?,?)", (tid, number + 1, kind, now, current[1]))
    tables = [m["table"] for m in matches]
    if all(m["match"] and not m["table"] for m in matches):
        tables = list(range(1, len(matches) + 1))
    else:
        # Multiple inactivity losses have no source table. Keep actual table numbers intact.
        unnamed = -sum(t == 0 for t in tables) + 1
        for i, table in enumerate(tables):
            if table == 0:
                tables[i] = unnamed
                unnamed += 1
    for table, match in zip(tables, matches):
        conn.execute("""INSERT INTO tournament_pairings(tournament_id,round_number,table_number,player_a,player_b,result,source,match_id,external_match)
            VALUES(?,?,?,?,?,?,'limitless',?,?)""", (tid, number + 1, table, mapping[match["players"][0]], mapping.get(match["players"][1]), _result(match), secrets.token_hex(16), match["match"]))
    conn.execute("""UPDATE tournaments SET phase='running',round_number=?,round_stage=?,game_format=?,
        round_started_at=?,timer_notice='',stages_json='[]' WHERE id=?""", (number + 1, kind, mode, now, tid))
    return f"已按 Limitless 第 {current[0]} 阶段第 {current[1]} 轮签表分配相同对阵与已公布结果"


def view(conn, tid, query):
    row = conn.execute("SELECT external_id,generation,auto_sync,snapshot_json,synced_at,retry_at,error FROM tournament_limitless WHERE tournament_id=?", (tid,)).fetchone()
    if row is None:
        return {}
    data = json.loads(row[3])
    with _lock:
        syncing = (_scope(conn), tid, row[1]) in _jobs
    result = {"url": f"{BASE}/tournament/{row[0]}", "auto_sync": bool(row[2]), "syncing": syncing,
              "synced_at": row[4], "retry_at": row[5], "error": row[6], "title": data.get("title", ""),
              "player_count": len(data.get("standings", [])), "match_count": len(data.get("pairings", []))}
    result["started"] = source_started(data)
    if query.get("owned"):
        result["mapping"] = "\n".join(f"{external}={username}" for external, username in conn.execute("""SELECT l.external_player,p.username
            FROM tournament_limitless_players l JOIN players p ON p.id=l.player_id WHERE l.tournament_id=? ORDER BY l.external_player""", (tid,)))
        result["external_players"] = sorted({p["player"] for p in data.get("standings", [])} | {p for m in data.get("pairings", []) for p in m["players"] if p})[:128]
    if query.get("external_view") not in ("pairings", "standings"):
        return result
    matches = data.get("pairings", [])
    rounds = sorted({(m["phase"], m["round"]) for m in matches})
    selected = (query.get("external_phase", 0), query.get("external_round", 0))
    if selected not in rounds:
        selected = rounds[-1] if rounds else (0, 0)
    entries = ([m for m in matches if (m["phase"], m["round"]) == selected]
               if query["external_view"] == "pairings" else data.get("standings", []))
    size = 12 if query["external_view"] == "pairings" else 20
    pages = max(1, (len(entries) + size - 1) // size)
    requested_page = query.get("external_page", 0)
    if type(requested_page) not in (int, float) or not 0 <= requested_page <= 2**53 - 1 or int(requested_page) != requested_page:
        requested_page = 0
    page = min(int(requested_page), pages - 1)
    return {**result, "view": query["external_view"], "rounds": [{"phase": a, "round": b} for a, b in rounds],
            "phases": data.get("phases", []), "phase": selected[0], "round": selected[1],
            "entries": entries[page * size:(page + 1) * size], "page": page, "pages": pages}
