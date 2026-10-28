"""Account task progress and copper rewards; mutations run inside the caller's transaction."""
import json
import secrets
import time
import shop_store
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone

CHINA_TIME = timezone(timedelta(hours=8))
SEASON_REWARDS = ((1, 80), (3, 60), (10, 40))
FIRST_SEASON_END = int(datetime(2026, 12, 1, tzinfo=CHINA_TIME).timestamp())
CATALOGUE_VERSION = 5
REMOVAL_GROUP = "items_barriers_removed"
LEGACY_REMOVAL_GROUPS = ("items_destroyed", "barriers_destroyed")
MAX_COUNTER = 1_000_000
TASK_CARD_NAMES = {
    "spell-fdn-069": "「青ノ花」",
    "spell-fdn-066": "「妖精ノ巡礼」",
    "spell-fdf-052": "幻波「赤眼催眠」",
    "spell-ucs-041": "日符「皇家烈焰」",
    "spell-fdf-056": "投钱「宵越ノ钱」",
    "character-kmo-001": "彼岸的渡者「小野冢小町」",
    "spell-fdf-068": "门符「最后ノ理想国」",
    "character-htk-002": "香霖堂的谜之妖怪「朱鹭子」",
    "character-lof-001": "活力四射的冰之勇者「琪露诺」",
    "character-fdf-ex03": "魔神复诵「圣白莲」",
    "82": "八坂的神风「八坂神奈子」",
    "118": "空观剑「六根清净斩」",
    "121": "幻世「the world」",
    "spell-fdf-008": "魔炮「Final Master Spark」",
}


def task(group, title, metric, target=1, *, tier="basic", aggregation="sum", cards=(), **conditions):
    return {"group": group, "title": title, "metric": metric, "target": target,
            "tier": tier, "aggregation": aggregation, "conditions": conditions, "cards": cards}


# Draw an outer group uniformly, then draw one of its variants uniformly. Stable
# group/key names and a frozen definition in each assignment decouple live days
# from future catalogue additions, removal, wording and target changes.
CATALOGUE = [
    task("ranked_win", "段位匹配获得 1 场胜利", "matches", mode="ranked", won=True),
    task("player_damage", "任意匹配对敌方玩家累计造成 40 点伤害", "player_damage", 40),
    {**task("color_win", "", "matches", won=True), "variants": [
        {"key": color, "title": f"使用{color}色自机在任意匹配获得胜利", "leader_color": color}
        for color in ("黑", "绿", "红", "蓝", "黄")]},
    task("units_destroyed", "任意匹配累计消灭 10 个单位", "units_destroyed", 10),
    task(REMOVAL_GROUP, "任意匹配累计牺牲、移除、消灭 4 个道具或结界", REMOVAL_GROUP, 4),
    task("exploration_win", "探索幻想乡模式匹配获得 1 场胜利（两种亚种皆可）", "matches", mode="exploration_any", won=True),
    task("fast_spells", "任意匹配累计使用 15 次高速符卡", "fast_spells", 15),
    task("non_spells", "任意匹配累计使用 10 次非符", "non_spells", 10),
    task("character_spells", "任意匹配累计使用 12 次角色符卡", "character_spells", 12),
    task("ranked_matches", "累计进行 3 次段位匹配（不计胜负）", "matches", 3, mode="ranked"),
    task("unit_cards", "任意匹配累计使用 24 次单位牌", "unit_cards", 24),
    task("tokens_created", "任意匹配累计制造 20 个衍生物", "tokens_created", 20),
    task("spell_counters", "使用高速符卡反制或间接反制符卡累计 8 次", "spell_counters", 8,
         cards=("spell-fdn-069", "spell-fdn-066", "spell-fdf-052"),
         detail="包含「青ノ花」、「妖精ノ巡礼」、幻波「赤眼催眠」的间接反制。"),
    task("death_triggers", "任意匹配累计触发死去时效果 10 次", "death_triggers", 10),
    task("life_recovered", "任意匹配累计回复 20 生命值", "life_recovered", 20),
    task("ranked_wins", "段位匹配累计 3 胜", "matches", 3, tier="advanced", mode="ranked", won=True),
    task("special_win", "段位匹配投钱胜利／门符「最后ノ理想国」胜利／日符「皇家烈焰」击杀敌方玩家 1 次（玩家任选一）",
         "matches", tier="advanced", mode="ranked", won=True,
         cards=("character-kmo-001", "spell-fdf-068", "spell-ucs-041"),
         card_labels={"character-kmo-001": "投钱"},
         any_of=[{"win_reason": "coin"}, {"win_reason": "gate"}, {"royal_kill": True}]),
    task("mill_win", "段位匹配获胜 1 次，胜利时对方牌库不多于 5 张", "matches", tier="advanced", mode="ranked", won=True, enemy_deck_max=5),
    task("leader_win", "段位匹配使用香霖堂的谜之妖怪「朱鹭子」／活力四射的冰之勇者「琪露诺」／魔神复诵「圣白莲」／八坂的神风「八坂神奈子」自机胜利 1 次（玩家任选一）",
         "matches", tier="advanced", mode="ranked", won=True,
         cards=("character-htk-002", "character-lof-001", "character-fdf-ex03", "82"),
         any_of=[{"leader_id": card_id} for card_id in ("character-htk-002", "character-lof-001", "character-fdf-ex03", "82")]),
    task("signature_spell", "在同一场段位匹配中使用空观剑「六根清净斩」／幻世「the world」／魔炮「Final Master Spark」至少 1 次并获胜（玩家任选一）",
         "cast_card", tier="advanced", mode="ranked", won=True,
         cards=("118", "121", "spell-fdf-008"),
         any_of=[{"card_id": card_id} for card_id in ("118", "121", "spell-fdf-008")]),
    task("healthy_win", "段位匹配胜利时我方拥有不少于 32 血", "final_life", 32, tier="advanced", aggregation="max", mode="ranked", won=True),
    task("overkill_win", "段位匹配胜利时对敌方玩家造成不少于 9 点过量伤害", "overkill", 9, tier="advanced", aggregation="max", mode="ranked", won=True),
    task("no_combat_win", "段位匹配胜利时我方单位未对敌方玩家造成战斗伤害", "matches", tier="advanced", mode="ranked", won=True, no_unit_combat_damage=True),
]


@contextmanager
def transaction(conn):
    """Own standalone API transactions without committing an enclosing match."""
    if conn.in_transaction:
        yield
    else:
        with conn:
            yield


def initialize(conn):
    shop_store.initialize(conn)
    conn.execute("""CREATE TABLE IF NOT EXISTS task_wallets (
        player_id INTEGER PRIMARY KEY, coins INTEGER NOT NULL DEFAULT 0 CHECK(coins>=0),
        FOREIGN KEY(player_id) REFERENCES players(id))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS task_daily (
        player_id INTEGER NOT NULL, day TEXT NOT NULL, wins INTEGER NOT NULL DEFAULT 0,
        streak INTEGER NOT NULL DEFAULT 0, best_streak INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(player_id,day), FOREIGN KEY(player_id) REFERENCES players(id))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS task_daily_assignments (
        player_id INTEGER NOT NULL, day TEXT NOT NULL, slot INTEGER NOT NULL CHECK(slot BETWEEN 0 AND 2),
        instance_id TEXT NOT NULL, group_id TEXT NOT NULL, definition TEXT NOT NULL,
        progress INTEGER NOT NULL DEFAULT 0, current_streak INTEGER NOT NULL DEFAULT 0,
        claimed INTEGER NOT NULL DEFAULT 0, rerolled INTEGER NOT NULL DEFAULT 0,
        previous_id TEXT NOT NULL DEFAULT '', PRIMARY KEY(player_id,day,slot),
        FOREIGN KEY(player_id) REFERENCES players(id))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS task_match_evidence (
        match_id TEXT PRIMARY KEY, recorded_at INTEGER NOT NULL, evidence TEXT NOT NULL)""")
    conn.execute("""CREATE TABLE IF NOT EXISTS task_rewards (
        player_id INTEGER NOT NULL, category TEXT NOT NULL, period TEXT NOT NULL,
        task TEXT NOT NULL, coins INTEGER NOT NULL CHECK(coins>0), awarded_at INTEGER NOT NULL,
        PRIMARY KEY(player_id,category,period,task), FOREIGN KEY(player_id) REFERENCES players(id))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS task_seasons (
        id INTEGER PRIMARY KEY, title TEXT NOT NULL, started_at INTEGER NOT NULL,
        ended_at INTEGER, ends_at INTEGER)""")
    if "ends_at" not in {r[1] for r in conn.execute("PRAGMA table_info(task_seasons)")}:
        conn.execute("ALTER TABLE task_seasons ADD COLUMN ends_at INTEGER")
    conn.execute("""CREATE TABLE IF NOT EXISTS task_season_results (
        season_id INTEGER NOT NULL, player_id INTEGER NOT NULL, position INTEGER NOT NULL,
        coins INTEGER NOT NULL, PRIMARY KEY(season_id,player_id),
        FOREIGN KEY(season_id) REFERENCES task_seasons(id),
        FOREIGN KEY(player_id) REFERENCES players(id))""")
    conn.execute("INSERT OR IGNORE INTO task_seasons(id,title,started_at,ends_at) VALUES(1,'第1赛季',?,?)", (int(time.time()), FIRST_SEASON_END))


def today(now=None):
    return (datetime.fromtimestamp(time.time() if now is None else now, CHINA_TIME) - timedelta(hours=6)).date().isoformat()


def reset_at(day):
    return int((datetime.fromisoformat(day).replace(tzinfo=CHINA_TIME, hour=6) + timedelta(days=1)).timestamp())


def choose_definition(tier, excluded=()):
    excluded = {REMOVAL_GROUP if group in LEGACY_REMOVAL_GROUPS else group for group in excluded}
    eligible = [entry for entry in CATALOGUE if entry["tier"] == tier and entry["group"] not in excluded]
    if not eligible:
        raise ValueError("当前没有可更换的任务")
    chosen = secrets.choice(eligible)
    definition = {key: value for key, value in chosen.items() if key not in ("variants", "cards")}
    definition["conditions"] = dict(definition["conditions"])
    variant = secrets.choice(chosen["variants"]) if chosen.get("variants") else {}
    definition["key"] = chosen["group"] + (":" + variant["key"] if variant else "")
    definition["title"] = variant.get("title", definition["title"])
    definition["conditions"].update({key: value for key, value in variant.items() if key not in ("key", "title", "cards", "card_labels")})
    labels = definition["conditions"].pop("card_labels", {}) | variant.get("card_labels", {})
    definition["card_refs"] = [{"id": card_id, "name": TASK_CARD_NAMES[card_id],
        **({"text": labels[card_id]} if card_id in labels else {})}
        for card_id in variant.get("cards", chosen.get("cards", ()))]
    definition["detail"] = definition["conditions"].pop("detail", "")
    definition["reward"] = 1 if tier == "basic" else 3
    definition["version"] = CATALOGUE_VERSION
    return definition


def put_assignment(conn, player_id, day, slot, definition, *, rerolled=False, previous_id=""):
    """Internal assignment writer; not reachable through a public account request."""
    instance_id = secrets.token_hex(8)
    conn.execute("""INSERT INTO task_daily_assignments
        (player_id,day,slot,instance_id,group_id,definition,rerolled,previous_id) VALUES(?,?,?,?,?,?,?,?)
        ON CONFLICT(player_id,day,slot) DO UPDATE SET instance_id=excluded.instance_id,
        group_id=excluded.group_id,definition=excluded.definition,progress=0,current_streak=0,
        claimed=0,rerolled=excluded.rerolled,previous_id=excluded.previous_id""",
                 (player_id, day, slot, instance_id, definition["group"], json.dumps(definition, ensure_ascii=False), int(rerolled), previous_id))
    return instance_id


def ensure_daily(conn, player_id, day):
    # First statement obtains SQLite's writer lock before reading or drawing.
    # Two processes cannot draw different tasks for the same account/day.
    conn.execute("INSERT OR IGNORE INTO task_daily(player_id,day) VALUES(?,?)", (player_id, day))
    # Upgrade each existing slot without discarding progress, rewards or reroll state.
    # If both legacy tasks were drawn today, both slots remain claimable today.
    if any(entry["group"] == REMOVAL_GROUP for entry in CATALOGUE):
        for slot, frozen in conn.execute("SELECT slot,definition FROM task_daily_assignments WHERE player_id=? AND day=? AND claimed=0", (player_id, day)).fetchall():
            old = json.loads(frozen)
            if old["group"] not in LEGACY_REMOVAL_GROUPS:
                continue
            replacement = choose_definition("basic", [entry["group"] for entry in CATALOGUE if entry["group"] != REMOVAL_GROUP])
            conn.execute("UPDATE task_daily_assignments SET group_id=?,definition=? WHERE player_id=? AND day=? AND slot=?",
                         (REMOVAL_GROUP, json.dumps(replacement, ensure_ascii=False), player_id, day, slot))
    existing = dict(conn.execute("SELECT slot,group_id FROM task_daily_assignments WHERE player_id=? AND day=?", (player_id, day)))
    for slot, tier in enumerate(("basic", "basic", "advanced")):
        if slot not in existing:
            definition = choose_definition(tier, existing.values())
            put_assignment(conn, player_id, day, slot, definition)
            existing[slot] = definition["group"]
    # Broaden today's affected, unclaimed tasks too; retain identity and earned progress.
    upgrades = {entry["group"]: 3 for entry in CATALOGUE if entry["conditions"].get("any_of")}
    if any(entry["group"] == "mill_win" for entry in CATALOGUE):
        upgrades["mill_win"] = 5
    for slot, frozen in conn.execute("SELECT slot,definition FROM task_daily_assignments WHERE player_id=? AND day=? AND claimed=0", (player_id, day)).fetchall():
        old = json.loads(frozen)
        if old["group"] not in upgrades or old.get("version", 0) >= upgrades[old["group"]]:
            continue
        replacement = choose_definition(old["tier"], [entry["group"] for entry in CATALOGUE if entry["group"] != old["group"]])
        conn.execute("UPDATE task_daily_assignments SET definition=? WHERE player_id=? AND day=? AND slot=?",
                     (json.dumps(replacement, ensure_ascii=False), player_id, day, slot))


def award(conn, player_id, category, period, task, coins, now):
    inserted = conn.execute("""INSERT OR IGNORE INTO task_rewards
        VALUES(?,?,?,?,?,?)""", (player_id, category, period, task, coins, now)).rowcount
    if inserted:
        conn.execute("""INSERT INTO task_wallets(player_id,coins) VALUES(?,?)
            ON CONFLICT(player_id) DO UPDATE SET coins=coins+excluded.coins""", (player_id, coins))
    return bool(inserted)


def valid_evidence(evidence):
    if not isinstance(evidence, dict) or type(evidence.get("version")) not in (int, float) or evidence["version"] != 1:
        return {}
    if not isinstance(evidence.get("players"), list) or len(evidence["players"]) != 2 or any(not isinstance(p, dict) for p in evidence["players"]):
        return {}
    try:
        encoded = json.dumps(evidence, ensure_ascii=False, allow_nan=False, separators=(",", ":"))
    except (ValueError, TypeError):
        return {}
    return evidence if len(encoded.encode("utf-8")) <= 32768 else {}


def counter(stats, name, *, signed=False):
    value = stats.get(name)
    # Godot's JSON parser represents JSON integers as floats when forwarding.
    # Range-check before conversion, including arbitrarily large JSON integers.
    if type(value) not in (int, float) or not (-MAX_COUNTER if signed else 0) <= value <= MAX_COUNTER:
        return None
    return int(value) if value == int(value) else None


def measurement(definition, mode, won, stats):
    filters = definition["conditions"]
    if "any_of" in filters:
        common = {key: value for key, value in filters.items() if key != "any_of"}
        # One qualifying match advances the group once, even if several choices match.
        return 1 if any((measurement({**definition, "conditions": {**common, **choice}}, mode, won, stats) or 0) > 0
                        for choice in filters["any_of"]) else None
    expected_mode = filters.get("mode")
    if expected_mode == "exploration_any":
        if mode not in ("exploration", "exploration_random"):
            return None
    elif expected_mode and mode != expected_mode:
        return None
    if filters.get("won") and not won:
        return None
    final = stats.get("final_game", stats)
    if not isinstance(final, dict):
        final = {}
    for name in ("leader_id", "leader_character", "win_reason"):
        if name in filters and final.get(name) != filters[name]:
            return None
    if "leader_color" in filters and (not isinstance(final.get("leader_colors"), list) or filters["leader_color"] not in final["leader_colors"]):
        return None
    if "enemy_deck_max" in filters:
        deck_size = counter(final, "enemy_final_deck")
        if deck_size is None or deck_size > filters["enemy_deck_max"]:
            return None
    if filters.get("royal_kill") and final.get("royal_flare_kill") is not True:
        return None
    if filters.get("no_unit_combat_damage") and counter(final, "unit_combat_player_damage") != 0:
        return None
    if filters.get("royal_only"):
        damage, royal = counter(final, "player_damage"), counter(final, "royal_flare_damage")
        if damage is None or damage <= 0 or damage != royal:
            return None
    if filters.get("exact_zero") and (counter(final, "unit_combat_player_damage") != 0 or counter(final, "enemy_final_life", signed=True) != 0):
        return None
    metric = definition["metric"]
    if metric == REMOVAL_GROUP and metric not in stats:
        # Older clients can still prove destructions, but not sacrifices or exiles.
        counts = [counter(stats, name) for name in LEGACY_REMOVAL_GROUPS]
        return min(MAX_COUNTER, sum(counts)) if all(value is not None for value in counts) else None
    if metric == "matches":
        return 1
    if metric == "streak":
        return int(won)
    if metric == "cast_card":
        casts = (final if filters.get("won") else stats).get("cast_cards", {})
        return counter(casts, filters["card_id"]) if isinstance(casts, dict) else None
    if metric == "overkill":
        life = counter(final, "enemy_final_life", signed=True)
        damage = counter(final, "overkill")
        return min(damage, max(0, -life)) if life is not None and damage is not None else None
    if metric == "final_life":
        life = counter(final, "final_life", signed=True)
        return max(0, life) if life is not None else None
    return counter(stats, metric)


def record_match(conn, players, winner, now=None, *, mode="ranked", evidence=None, match_id=None):
    """Called only for a newly settled automatic match, never a retry or tournament."""
    now = int(time.time()) if now is None else now
    day = today(now)
    evidence = valid_evidence(evidence)
    if match_id and evidence:
        conn.execute("INSERT OR IGNORE INTO task_match_evidence VALUES(?,?,?)", (match_id, now, json.dumps(evidence, ensure_ascii=False)))
    for actor, player_id in enumerate(players):
        ensure_daily(conn, player_id, day)
        stats = evidence["players"][actor] if evidence else {}
        rows = conn.execute("SELECT slot,definition,progress,current_streak FROM task_daily_assignments WHERE player_id=? AND day=? AND claimed=0", (player_id, day)).fetchall()
        for slot, frozen, progress, streak in rows:
            definition = json.loads(frozen)
            value = measurement(definition, mode, actor == winner, stats)
            if value is None:
                continue
            if definition["metric"] == "streak":
                streak = streak + 1 if value else 0
                progress = max(progress, streak)
            elif definition["aggregation"] == "max":
                progress = max(progress, value)
            else:
                progress = min(MAX_COUNTER, progress + value)
            conn.execute("UPDATE task_daily_assignments SET progress=?,current_streak=? WHERE player_id=? AND day=? AND slot=?", (progress, streak, player_id, day, slot))


def mutate(conn, player_id, action, data, now=None):
    now = int(time.time()) if now is None else now
    day = today(now)
    if data.get("day") != day:
        raise ValueError("每日任务已于北京时间 06:00 更新，请使用新任务")
    slot, instance_id = data.get("slot"), data.get("task_id")
    if type(slot) not in (int, float) or slot not in (0, 1, 2) or not isinstance(instance_id, str) or len(instance_id) != 16:
        raise ValueError("任务标识无效")
    slot = int(slot)
    with transaction(conn):
        ensure_daily(conn, player_id, day)
        row = conn.execute("SELECT instance_id,definition,progress,claimed,rerolled,previous_id FROM task_daily_assignments WHERE player_id=? AND day=? AND slot=?", (player_id, day, slot)).fetchone()
        if action == "task_reroll" and row[4] and instance_id == row[5]:
            return "任务已更换"  # Lost response retry, without another draw.
        if instance_id != row[0]:
            raise ValueError("任务已更换，请使用新任务")
        definition = json.loads(row[1])
        if action == "task_claim":
            if row[2] < definition["target"]:
                raise ValueError("任务尚未完成")
            award(conn, player_id, "daily", day, "slot_" + str(slot), definition["reward"], now)
            conn.execute("UPDATE task_daily_assignments SET claimed=1 WHERE player_id=? AND day=? AND slot=?", (player_id, day, slot))
            return "奖励已领取"
        if action != "task_reroll":
            raise ValueError("未知任务操作")
        if row[3]:
            raise ValueError("已领取奖励的任务不能更换")
        if row[4]:
            raise ValueError("每条每日任务只能更换一次")
        groups = [r[0] for r in conn.execute("SELECT group_id FROM task_daily_assignments WHERE player_id=? AND day=?", (player_id, day))]
        replacement = choose_definition(definition["tier"], groups)
        put_assignment(conn, player_id, day, slot, replacement, rerolled=True, previous_id=instance_id)
        return "任务已更换，进度从 0 开始"


def season_reward(position):
    for limit, coins in SEASON_REWARDS:
        if 0 < position <= limit:
            return coins
    return 30 if position > 0 else 0


def close_season(conn, season_id, now=None):
    """Trusted maintenance operation: snapshot final ranks and pay one tier atomically.

    The caller must use `with conn:`. Repeating the same season ID is harmless.
    Rank resets and season duration are deliberately separate from reward settlement.
    """
    if type(season_id) is not int:
        raise ValueError("赛季编号无效")
    season = conn.execute("SELECT title,ended_at FROM task_seasons WHERE id=?", (season_id,)).fetchone()
    if season is None:
        raise ValueError("赛季不存在")
    if season[1] is not None:
        return {"season": season_id, "settled": True, "already_settled": True}
    now = int(time.time()) if now is None else now
    # Same ordering as account_store.player_rank, including equal-Elo tiebreaks.
    sages = conn.execute("SELECT id FROM players WHERE rank_step=11 ORDER BY elo DESC,id ASC").fetchall()
    for position, (player_id,) in enumerate(sages, 1):
        coins = season_reward(position)
        conn.execute("INSERT INTO task_season_results VALUES(?,?,?,?)", (season_id, player_id, position, coins))
        award(conn, player_id, "season", str(season_id), "sage", coins, now)
    conn.execute("UPDATE task_seasons SET ended_at=? WHERE id=?", (now, season_id))
    next_id = season_id + 1
    conn.execute("INSERT INTO task_seasons(id,title,started_at) VALUES(?,?,?)", (next_id, f"第{next_id}赛季", now))
    return {"season": season_id, "settled": True, "players": len(sages), "next_season": next_id}


def tick(conn, now=None):
    now = int(time.time()) if now is None else now
    if not conn.execute("SELECT 1 FROM task_seasons WHERE ended_at IS NULL AND ends_at<=? LIMIT 1", (now,)).fetchone():
        return
    with conn:
        # Acquire the writer lock before checking the final snapshot, including
        # when two account processes notice the deadline at the same time.
        conn.execute("UPDATE task_seasons SET ends_at=ends_at WHERE ended_at IS NULL AND ends_at<=?", (now,))
        due = conn.execute("SELECT id,ends_at FROM task_seasons WHERE ended_at IS NULL AND ends_at<=? ORDER BY id", (now,)).fetchall()
        for season_id, ends_at in due:
            close_season(conn, season_id, ends_at)


def snapshot(conn, player_id, now=None):
    now = int(time.time()) if now is None else now
    day = today(now)
    with transaction(conn):
        ensure_daily(conn, player_id, day)
        balance = conn.execute("SELECT coins FROM task_wallets WHERE player_id=?", (player_id,)).fetchone()
        rows = conn.execute("SELECT slot,instance_id,definition,progress,current_streak,claimed,rerolled FROM task_daily_assignments WHERE player_id=? AND day=? ORDER BY slot", (player_id, day)).fetchall()
        assignments = []
        for slot, instance_id, frozen, progress, streak, claimed, rerolled in rows:
            definition = json.loads(frozen)
            assignments.append({"slot": slot, "id": instance_id, "group": definition["group"],
                "key": definition["key"], "tier": definition["tier"], "title": definition["title"],
                "detail": definition.get("detail", ""), "card_refs": definition.get("card_refs", []), "reward": definition["reward"], "target": definition["target"],
                "aggregation": definition["aggregation"], "progress": progress, "current_streak": streak,
                "completed": progress >= definition["target"], "claimed": bool(claimed), "rerolled": bool(rerolled)})
        current = conn.execute("SELECT id,title,ends_at FROM task_seasons WHERE ended_at IS NULL ORDER BY id DESC LIMIT 1").fetchone()
        previous = conn.execute("""SELECT s.id,s.title,s.ended_at,COALESCE(r.position,0),COALESCE(r.coins,0)
            FROM task_seasons s LEFT JOIN task_season_results r ON r.season_id=s.id AND r.player_id=?
            WHERE s.ended_at IS NOT NULL ORDER BY s.id DESC LIMIT 1""", (player_id,)).fetchone()
    return {"coins": balance[0] if balance else 0, "server_time": now,
            "purchased_product_ids": shop_store.owned(conn, player_id),
            "daily": {"day": day, "resets_at": reset_at(day), "tasks": assignments,
                      "claimable": sum(1 for item in assignments if item["completed"] and not item["claimed"])},
            "season": {"id": current[0], "title": current[1], "ends_at": current[2]},
            "previous": {"id": previous[0], "title": previous[1], "ended_at": previous[2], "position": previous[3], "coins": previous[4]} if previous else {}}
