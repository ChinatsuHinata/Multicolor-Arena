"""Multi-stage competitions. All points, progression and grants are authoritative."""
import json
import math
import secrets
import time
import task_store
from tournament_pairing import knockout_pairs, swiss_pairs

KINDS = ("swiss", "single_elimination", "double_elimination", "round_robin")
GAME_FORMATS = (1, 2, 3, 4, 5, 6, 7)  # 6=BO5, 7=BO2; legacy IDs stay stable.
DEFAULT_REWARDS = {"champion": 50, "runner_up": 40, "semifinalist": 20}
DEFAULT_POINTS = {"win": 3, "draw": 1, "loss": 0, "bye": 3, "scores": {}}


def integer(value, low=0, high=1000000):
    return type(value) in (int, float) and low <= value <= high and int(value) == value


def initialize(conn):
    for table, fields in {
        "tournaments": {"stages_json": "TEXT NOT NULL DEFAULT '[]'", "stage_index": "INTEGER NOT NULL DEFAULT 0",
                        "rewards_json": "TEXT NOT NULL DEFAULT '{\"champion\":50,\"runner_up\":40,\"semifinalist\":20}'",
                        "rewards_paid": "INTEGER NOT NULL DEFAULT 0"},
        "tournament_rounds": {"stage_index": "INTEGER NOT NULL DEFAULT -1", "stage_round": "INTEGER NOT NULL DEFAULT 0"},
        "tournament_pairings": {"score_a": "INTEGER", "score_b": "INTEGER", "report_score_a": "TEXT", "report_score_b": "TEXT"},
    }.items():
        columns = {row[1] for row in conn.execute(f"PRAGMA table_info({table})")}
        for name, definition in fields.items():
            if name not in columns:
                conn.execute(f"ALTER TABLE {table} ADD COLUMN {name} {definition}")
    conn.execute("""CREATE TABLE IF NOT EXISTS tournament_stage_members(
        tournament_id INTEGER,stage_index INTEGER,player_id INTEGER,seed INTEGER,
        PRIMARY KEY(tournament_id,stage_index,player_id))""")


def stages_input(value):
    if not isinstance(value, list) or not 1 <= len(value) <= 12:
        raise ValueError("请设置 1–12 个比赛阶段")
    result = []
    for i, stage in enumerate(value):
        if not isinstance(stage, dict) or stage.get("kind") not in KINDS:
            raise ValueError("阶段赛制须为瑞士轮、单败、双败或循环赛")
        kind = stage["kind"]
        game = stage.get("game_format", 3)
        rounds = stage.get("rounds", 0)
        if not integer(game, 1, 7) or game not in GAME_FORMATS or not integer(rounds, 0, 127):
            raise ValueError("阶段局制或轮数无效")
        if game == 7 and kind in ("single_elimination", "double_elimination"):
            raise ValueError("BO2 允许平局，请用于瑞士轮或循环赛；淘汰阶段请选择 BO1/BO3/BO5")
        points = stage.get("points", DEFAULT_POINTS)
        if not isinstance(points, dict):
            raise ValueError("计分规则无效")
        points = {**DEFAULT_POINTS, **points}
        if any(not integer(points[k], 0, 10000) for k in ("win", "draw", "loss", "bye")):
            raise ValueError("胜、平、负、轮空分数须为 0–10000 的整数")
        scores = points.get("scores", {})
        if not isinstance(scores, dict) or len(scores) > 16:
            raise ValueError("比分给分表无效")
        for score, amount in scores.items():
            try:
                pair = [int(x) for x in score.split(":")]
                validate_score(pair, game, allow_draw=True)
            except (ValueError, AttributeError):
                raise ValueError("比分给分须使用此局制的有效比分，例如 2:0、2:1、1:2、0:2") from None
            if not integer(amount, 0, 10000):
                raise ValueError("比分积分须为 0–10000 的整数")
        advance = stage.get("advance", {"mode": "all"})
        if not isinstance(advance, dict) or advance.get("mode") not in ("all", "rank", "points"):
            raise ValueError("晋级条件无效")
        advance = {"count": 2, "points": 6, "early": False, "eliminate_losses": 0, **advance}
        if not integer(advance["count"], 1, 128) or not integer(advance["points"], 0, 1000000) or not integer(advance["eliminate_losses"], 0, 127) or type(advance["early"]) is not bool:
            raise ValueError("晋级名额、积分或提前淘汰条件无效")
        title = stage.get("name", f"第 {i+1} 阶段")
        if not isinstance(title, str) or not 1 <= len(title.strip()) <= 40:
            raise ValueError("阶段名称须为 1–40 字符")
        result.append({"name": title.strip(), "kind": kind, "game_format": int(game), "rounds": int(rounds),
                       "points": points, "advance": advance})
    return result


def rewards_input(value):
    if not isinstance(value, dict) or set(value) != set(DEFAULT_REWARDS) or any(not integer(v) for v in value.values()):
        raise ValueError("冠军、亚军、四强奖励须为 0–1000000 的整数")
    return {k: int(v) for k, v in value.items()}


def config(conn, tid):
    row = conn.execute("SELECT stages_json,stage_index,rewards_json,rewards_paid FROM tournaments WHERE id=?", (tid,)).fetchone()
    return {"stages": json.loads(row[0]), "stage_index": row[1], "rewards": json.loads(row[2]), "rewards_paid": bool(row[3])}


def validate_score(score, game, allow_draw=True, result=None):
    target = {3: 2, 6: 3, 7: 2}.get(game, 1)
    if not isinstance(score, list) or len(score) != 2 or any(not integer(v, 0, target) for v in score):
        raise ValueError("大比分无效")
    a, b = map(int, score)
    winner = -1 if a == b else 0 if a > b else 1
    if game == 7:
        valid = a + b <= 2
    else:
        valid = (a == b and a < target) or (max(a, b) == target and min(a, b) < target)
    if not valid or winner == -1 and not allow_draw or result is not None and winner != result:
        raise ValueError("大比分与局制或胜负结果不一致")
    return [a, b]


def active_stage(conn, tid):
    settings = config(conn, tid)
    return settings["stages"][settings["stage_index"]] if settings["stages"] else None


def score_for_result(conn, tid, data, result):
    stage = active_stage(conn, tid)
    game = stage["game_format"] if stage else conn.execute("SELECT game_format FROM tournaments WHERE id=?", (tid,)).fetchone()[0]
    if "scores" not in data:
        if stage and stage["points"]["scores"]:
            raise ValueError("此比赛按大比分给分，请填写实际大比分")
        target = {3: 2, 6: 3, 7: 2}.get(game, 1)
        return [0, 0] if result == -1 else [target, 0] if result == 0 else [0, target]
    return validate_score(data["scores"], game, result=result)


def standings(conn, tid, index=None):
    settings = config(conn, tid)
    index = settings["stage_index"] if index is None else index
    stage = settings["stages"][index]
    members = conn.execute("""SELECT m.player_id,p.nickname,m.seed FROM tournament_stage_members m
        JOIN players p ON p.id=m.player_id WHERE m.tournament_id=? AND m.stage_index=? ORDER BY m.seed""", (tid, index)).fetchall()
    if not members and index == 0:
        members = conn.execute("SELECT m.player_id,p.nickname,m.seed FROM tournament_members m JOIN players p ON p.id=m.player_id WHERE tournament_id=? AND in_roster=1 ORDER BY m.seed,m.player_id", (tid,)).fetchall()
    players = {id: {"player_id": id, "nickname": name or f"选手{seed:02d}", "seed": seed, "points": 0,
                    "wins": 0, "draws": 0, "losses": 0, "byes": 0, "buchholz": 0, "state": "active"} for id, name, seed in members}
    history = conn.execute("""SELECT p.player_a,p.player_b,p.result,p.score_a,p.score_b,r.stage_round FROM tournament_pairings p
        JOIN tournament_rounds r ON r.tournament_id=p.tournament_id AND r.number=p.round_number
        WHERE p.tournament_id=? AND r.stage_index=? AND p.result IS NOT NULL ORDER BY r.number,p.table_number""", (tid, index)).fetchall()
    opponents = {id: [] for id in players}
    knockout = stage["kind"] in ("single_elimination", "double_elimination")
    max_losses = 2 if stage["kind"] == "double_elimination" else 1
    eliminations = {}
    for a, b, result, sa, sb, round_number in history:
        if a not in players or b is not None and b not in players:
            continue
        if b is None:
            players[a]["byes"] += 1
            if not knockout:
                players[a]["points"] += stage["points"]["bye"]
            continue
        for player, other, actor, score, against in ((a, b, 0, sa, sb), (b, a, 1, sb, sa)):
            entry = players[player]
            key = "draw" if result == -1 else "win" if result == actor else "loss"
            entry[{"win": "wins", "draw": "draws", "loss": "losses"}[key]] += 1
            entry["points"] += stage["points"]["scores"].get(f"{score}:{against}", stage["points"][key])
            opponents[player].append(other)
            if knockout and entry["losses"] >= max_losses:
                entry["state"] = "eliminated"
                eliminations[player] = round_number
    for player, faced in opponents.items():
        players[player]["buchholz"] = sum(players[other]["points"] for other in faced)
    ordered = sorted(players.values(), key=lambda e: (-e["points"], -e["buchholz"], -e["wins"], e["seed"], e["player_id"]))
    if knockout:
        ordered.sort(key=lambda e: (e["state"] == "eliminated", -eliminations.get(e["player_id"], 100000)))
        for entry in ordered:
            if entry["player_id"] in eliminations:
                stamp = eliminations[entry["player_id"]]
                entry["placement"] = 1 + sum(1 for e in ordered if eliminations.get(e["player_id"], 100000) > stamp)
        alive = [e for e in ordered if e["state"] == "active"]
        if len(alive) == 1:
            alive[0]["placement"] = 1
    else:
        completed = conn.execute("SELECT COALESCE(MAX(stage_round),0) FROM tournament_rounds WHERE tournament_id=? AND stage_index=?", (tid, index)).fetchone()[0]
        unfinished = conn.execute("""SELECT COUNT(*) FROM tournament_pairings p JOIN tournament_rounds r ON r.tournament_id=p.tournament_id AND r.number=p.round_number
            WHERE p.tournament_id=? AND r.stage_index=? AND p.result IS NULL""", (tid, index)).fetchone()[0]
        if not unfinished:
            advance = stage["advance"]
            if advance["early"]:
                remaining = max(0, round_count(stage, len(players)) - completed)
                max_points = max(stage["points"][k] for k in ("win", "draw", "loss", "bye"))
                max_points = max([max_points, *stage["points"]["scores"].values()])
                for entry in ordered:
                    if advance["mode"] == "points" and entry["points"] >= advance["points"]:
                        entry["state"] = "advanced"
                    elif advance["eliminate_losses"] and entry["losses"] >= advance["eliminate_losses"] or advance["mode"] == "points" and entry["points"] + remaining * max_points < advance["points"]:
                        entry["state"] = "eliminated"
    for rank, entry in enumerate(ordered, 1):
        entry["rank"] = rank
    return ordered


def round_count(stage, count):
    if stage["kind"] == "round_robin":
        return count - 1 if count % 2 == 0 else count
    return stage["rounds"] or max(1, math.ceil(math.log2(max(2, count))))


def robin_pairs(ids, number):
    ring = list(ids)
    if len(ring) % 2:
        ring.append(None)
    for _ in range(number - 1):
        ring = [ring[0], ring[-1], *ring[1:-1]]
    return [(a, b) if a is not None else (b, a) for a, b in zip(ring[:len(ring)//2], reversed(ring[len(ring)//2:]))]


def advance_round(conn, tid, expected, now=None):
    now = int(time.time()) if now is None else now
    number, phase = conn.execute("SELECT round_number,phase FROM tournaments WHERE id=?", (tid,)).fetchone()
    if number != expected:
        raise ValueError("轮次已变化，请刷新后重试")
    if phase not in ("locked", "running"):
        raise ValueError("请先结束签到并确定参赛名单")
    if conn.execute("SELECT 1 FROM tournament_pairings WHERE tournament_id=? AND round_number=? AND result IS NULL", (tid, number)).fetchone():
        raise ValueError("本轮仍有未结束或待确认对局")
    settings = config(conn, tid)
    index = settings["stage_index"]
    if number == 0:
        roster = conn.execute("SELECT player_id,seed FROM tournament_members WHERE tournament_id=? AND in_roster=1 ORDER BY seed,player_id", (tid,)).fetchall()
        if not 2 <= len(roster) <= 128:
            raise ValueError("比赛需要 2–128 名已签到选手")
        conn.executemany("INSERT OR IGNORE INTO tournament_stage_members VALUES(?,?,?,?)", ((tid, 0, id, seed) for id, seed in roster))
    while True:
        stage = settings["stages"][index]
        entries = standings(conn, tid, index)
        completed = conn.execute("SELECT COUNT(*) FROM tournament_rounds WHERE tournament_id=? AND stage_index=?", (tid, index)).fetchone()[0]
        active = [e for e in entries if e["state"] == "active"]
        knockout = stage["kind"] in ("single_elimination", "double_elimination")
        cut = stage["advance"]["count"] if index < len(settings["stages"]) - 1 and stage["advance"]["mode"] == "rank" else 1
        finished = len(active) <= cut if knockout else completed >= round_count(stage, len(entries)) or not active
        if not finished:
            break
        if index == len(settings["stages"]) - 1:
            conn.execute("UPDATE tournaments SET phase='complete',timer_notice='' WHERE id=?", (tid,))
            award_rewards(conn, tid, entries)
            return "比赛已结束，铜钱奖励已自动发放"
        advance = stage["advance"]
        if advance["mode"] == "rank":
            selected = entries[:advance["count"]]
        elif advance["mode"] == "points":
            selected = [e for e in entries if e["points"] >= advance["points"] and (e["state"] != "eliminated" or knockout)]
        else:
            selected = active if knockout else [e for e in entries if e["state"] != "eliminated"]
        if len(selected) < 2:
            raise ValueError("满足晋级条件的选手不足 2 人，请调整下一阶段的晋级门槛")
        index += 1
        conn.executemany("INSERT INTO tournament_stage_members VALUES(?,?,?,?)", ((tid, index, e["player_id"], i) for i, e in enumerate(selected, 1)))
        conn.execute("UPDATE tournaments SET stage_index=? WHERE id=?", (index, tid))
    if stage["kind"] == "swiss":
        if round_count(stage, len(entries)) > (len(entries) if len(entries) % 2 else len(entries) - 1):
            raise ValueError("瑞士轮轮数超过不重复对手的可用轮数")
        history = conn.execute("SELECT p.player_a,p.player_b FROM tournament_pairings p JOIN tournament_rounds r ON r.tournament_id=p.tournament_id AND r.number=p.round_number WHERE p.tournament_id=? AND r.stage_index=?", (tid, index)).fetchall()
        pairs = swiss_pairs(active, [(a, b) for a, b in history if b is not None], {a for a, b in history if b is None}) if len(active) > 1 else [(active[0]["player_id"], None)]
    elif stage["kind"] == "round_robin":
        ids = [e["player_id"] for e in sorted(entries, key=lambda e: e["seed"])]
        active_ids = {e["player_id"] for e in active}
        # A withdrawn/early-qualified opponent is skipped without awarding free points.
        pairs = [(a, b) for a, b in robin_pairs(ids, completed + 1) if a in active_ids and (b is None or b in active_ids)]
    elif stage["kind"] == "single_elimination":
        if completed == 0:
            pairs = knockout_pairs([e["player_id"] for e in sorted(active, key=lambda e: e["seed"])])
        else:
            previous = conn.execute("""SELECT p.player_a,p.player_b,p.result FROM tournament_pairings p
                JOIN tournament_rounds r ON r.tournament_id=p.tournament_id AND r.number=p.round_number
                WHERE p.tournament_id=? AND r.stage_index=? AND r.stage_round=? ORDER BY p.table_number""", (tid, index, completed)).fetchall()
            winners = [a if result == 0 else b for a, b, result in previous]
            pairs = list(zip(winners[::2], winners[1::2]))
            if len(winners) % 2:
                pairs.append((winners[-1], None))
    else:
        pairs = []
        pools = [[e for e in active if e["losses"] == losses] for losses in (0, 1)] if stage["kind"] == "double_elimination" else [active]
        if len(active) == 2:
            pools = [active]  # Grand final resets when the unbeaten entrant loses.
        for pool in pools:
            # High seed meets low seed; byes rotate by historical bye count.
            pool.sort(key=lambda e: (e["byes"], e["seed"]))
            if len(pool) % 2:
                pairs.append((pool.pop(0)["player_id"], None))
            pool.sort(key=lambda e: e["seed"])
            pairs.extend((pool[i]["player_id"], pool[-1-i]["player_id"]) for i in range(len(pool)//2))
    conn.execute("INSERT INTO tournament_rounds(tournament_id,number,stage,started_at,stage_index,stage_round) VALUES(?,?,?,?,?,?)", (tid, number+1, stage["kind"], now, index, completed+1))
    conn.executemany("INSERT INTO tournament_pairings(tournament_id,round_number,table_number,player_a,player_b,result,source,match_id) VALUES(?,?,?,?,?,?,?,?)", ((tid, number+1, i, a, b, 0 if b is None else None, "bye" if b is None else "", secrets.token_hex(16)) for i, (a, b) in enumerate(pairs, 1)))
    conn.execute("UPDATE tournaments SET phase='running',round_number=?,round_stage=?,game_format=?,round_started_at=?,timer_notice='' WHERE id=?", (number+1, stage["kind"], stage["game_format"], now, tid))
    return f"{stage['name']} · 第 {completed+1} 轮对阵已编排"


def final_standings(conn, tid):
    settings = config(conn, tid)
    entries = standings(conn, tid)
    ordered = [{**e, "placement": e.get("placement", e["rank"]), "stage_name": settings["stages"][settings["stage_index"]]["name"]} for e in entries]
    known = {e["player_id"] for e in ordered}
    for index in range(settings["stage_index"] - 1, -1, -1):
        previous = standings(conn, tid, index)
        offset = len(ordered)
        last_place, group_place = None, offset + 1
        for entry in previous:
            if entry["player_id"] not in known:
                local_place = entry.get("placement", entry["rank"])
                if local_place != last_place:
                    group_place = len(ordered) + 1
                    last_place = local_place
                ordered.append({**entry, "placement": group_place, "stage_name": settings["stages"][index]["name"]})
                known.add(entry["player_id"])
    for entry in ordered:
        entry["rank"] = entry["placement"]
    return ordered


def award_rewards(conn, tid, entries):
    settings = config(conn, tid)
    if settings["rewards_paid"]:
        return
    # Keep semifinalists even when semis and final use separate stages.
    if settings["stages"]:
        entries = final_standings(conn, tid)
    for entry in entries:
        place = entry.get("placement", entry["rank"])
        key = "champion" if place == 1 else "runner_up" if place == 2 else "semifinalist" if place in (3, 4) else ""
        amount = settings["rewards"].get(key, 0)
        if amount:
            task_store.award(conn, entry["player_id"], "tournament", str(tid), "placement", amount, int(time.time()))
    conn.execute("UPDATE tournaments SET rewards_paid=1 WHERE id=?", (tid,))
