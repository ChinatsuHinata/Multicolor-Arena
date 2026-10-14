"""Rank floors, capped win bonuses, migration, settlement and Sage ordering."""
import importlib.util
import sys
import tempfile
from pathlib import Path

source = Path(__file__).resolve().parents[1] / "relay" / "account_store.py"
sys.path.insert(0, str(source.parent))
spec = importlib.util.spec_from_file_location("rank_store", source)
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)

assert store.advance_rank(0, 2, 2, True) == (1, 0, 3)
assert store.advance_rank(1, 2, 3, True) == (2, 0, 4)
assert store.advance_rank(2, 0, 2, True) == (2, 2, 3)
for step in (0, 1):
    assert store.advance_rank(step, 2, 8, False) == (step, 2, 0)
assert store.advance_rank(2, 0, 8, False) == (2, 0, 0)
assert store.advance_rank(2, 1, 0, False) == (2, 0, 0)
assert store.advance_rank(5, 1, 8, False) == (5, 0, 0)
assert store.advance_rank(5, 0, 8, False) == (4, 2, 0)
assert store.advance_rank(8, 0, 0, False) == (7, 2, 0)
assert store.advance_rank(10, 2, 5, True) == (11, 0, 6)
assert store.advance_rank(11, 0, 0, False) == (11, 0, 0)

scratch = source.parents[1] / "work" / "rank-tests"
scratch.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="TEST_ONLY_", dir=scratch) as directory:
    path = Path(directory) / "rank.sqlite3"
    conn = store.database(path)
    for index in range(3):
        conn.execute("INSERT INTO players(username,password_salt,password_hash,created_at) VALUES(?,?,?,0)",
                     (f"rank_{index}", b"salt", b"hash"))
    conn.commit()
    ids = [r[0] for r in conn.execute("SELECT id FROM players ORDER BY id")]
    assert store.player_rank(conn, ids[0]) == {"tier": 0, "level": 2, "stars": 0, "streak": 0, "position": 0}
    conn.execute("UPDATE players SET rank_step=10,rank_stars=2,rank_streak=2 WHERE id=?", (ids[0],))
    conn.execute("UPDATE players SET rank_step=11,elo=1400 WHERE id=?", (ids[2],))
    conn.commit()
    match_id = "e" * 32
    def request(action, **args):
        return store.handle_match(conn, {"action": action, "match_id": match_id, **args})
    request("create", players=ids[:2]);request("start")
    settled = request("settle", winner=0)
    assert settled["ranks"][0] == {"tier": 4, "level": 0, "stars": 0, "streak": 3, "position": 2}
    assert request("settle", winner=0) == settled
    conn.execute("UPDATE players SET elo=900 WHERE id=?", (ids[2],));conn.commit()
    assert store.player_rank(conn, ids[0])["position"] == 1
    assert request("settle", winner=0) == settled  # Historical receipt is stable.
    conn.close();conn = store.database(path)
    assert store.player_rank(conn, ids[0])["tier"] == 4
    assert request("settle", winner=0) == settled
    conn.execute("UPDATE players SET rank_step=5,rank_stars=0,rank_streak=4 WHERE id=?", (ids[1],))
    conn.commit()
    match_id = "f" * 32
    request("create", players=ids[:2]);request("start")
    demoted = request("settle", winner=0)
    fairy_rank = {"tier": 1, "level": 1, "stars": 2, "streak": 0, "position": 0}
    assert demoted["ranks"][1] == fairy_rank
    assert store.player_rank(conn, ids[1]) == fairy_rank
    assert request("settle", winner=0) == demoted
    assert store.player_rank(conn, ids[1]) == fairy_rank
    conn.close();conn = store.database(path)
    assert store.player_rank(conn, ids[1]) == fairy_rank
    assert request("settle", winner=0) == demoted
    conn.close()
print("PASS: rank bonuses, Fairy protection, Tengu demotion, progression, persistence and Sage leaderboard")
