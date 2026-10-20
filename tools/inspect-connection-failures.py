"""Read persisted server decisions; no writes, session tokens or account secrets."""
import argparse
import datetime
import json
from pathlib import Path
import re
import sqlite3
import time

parser = argparse.ArgumentParser(description="按对局 ID 或时间查询服务器断线归因与结算证据（只读）。")
parser.add_argument("--database", default="/home/codex/.local/share/multicolor-relay/data/players.sqlite3")
parser.add_argument("--match-id")
parser.add_argument("--hours", type=int, default=24)
parser.add_argument("--limit", type=int, default=100)
args = parser.parse_args()
if args.match_id and not re.fullmatch(r"[a-f0-9]{32}", args.match_id):
    parser.error("match-id 必须是 32 位小写十六进制对局 ID")
if not 1 <= args.hours <= 8760 or not 1 <= args.limit <= 1000:
    parser.error("hours 需为 1–8760，limit 需为 1–1000")
reasons = {"player_link_timeout": "单方连接／恢复超时", "player_abandoned": "玩家放弃原对局另开匹配",
           "both_links_unavailable": "双方链路异常，无法确认单方责任", "server_transport_error": "服务器转发异常",
           "sync_unconfirmed": "同步未完成，未确认单方责任", "pregame_disconnect": "赛前断线",
           "agreed_result": "双方确认的正常结果", "acknowledged_result": "在线方此前已确认的结果",
           "abandoned_unresolved": "原对局放弃但无足够单方判负证据"}
path = Path(args.database).resolve()
db = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True, timeout=10)
try:
    db.execute("PRAGMA query_only=ON")
    where, parameters = ("r.match_id=?", [args.match_id]) if args.match_id else ("r.recorded_at>=?", [int(time.time())-args.hours*3600])
    rows = db.execute(f"""SELECT r.match_id,r.recorded_at,r.status,r.winner,r.detail,
        m.player_a,a.nickname,m.player_b,b.nickname
        FROM match_resolutions r JOIN rating_matches m USING(match_id)
        JOIN players a ON a.id=m.player_a JOIN players b ON b.id=m.player_b
        WHERE {where} ORDER BY r.recorded_at DESC LIMIT ?""", [*parameters, args.limit]).fetchall()
    results = []
    for match_id, stamp, status, winner, detail, first, first_name, second, second_name in rows:
        decision = json.loads(detail)
        results.append({"对局ID": match_id, "时间": datetime.datetime.fromtimestamp(stamp).astimezone().isoformat(),
                        "状态": status, "胜方席位": winner+1 if winner in (0, 1) else None,
                        "原因": reasons.get(decision.get("reason"), decision.get("reason", "未记录")),
                        "双方": [{"席位": 1, "玩家ID": first, "昵称": first_name}, {"席位": 2, "玩家ID": second, "昵称": second_name}],
                        "服务器证据": decision.get("evidence", []), "是否故意": "网络证据不能可靠区分故意与意外"})
    print(json.dumps({"记录数": len(results), "对局": results}, ensure_ascii=False, indent=2))
finally:
    db.close()
