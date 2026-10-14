"""Trusted ranked match lifecycle, rating persistence and public API isolation."""
import importlib.util
import sqlite3
import sys
import tempfile
from pathlib import Path

source = Path(__file__).resolve().parents[1] / "relay" / "account_store.py"
sys.path.insert(0, str(source.parent))
spec = importlib.util.spec_from_file_location("match_account_store", source)
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)

with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "players.sqlite3"
    legacy_path = Path(directory) / "existing_matches.sqlite3"
    with sqlite3.connect(legacy_path) as existing:
        existing.execute("""CREATE TABLE rating_matches (
            match_id TEXT PRIMARY KEY, player_a INTEGER NOT NULL, player_b INTEGER NOT NULL,
            created_at INTEGER NOT NULL, started_at INTEGER, status TEXT NOT NULL DEFAULT 'pending',
            winner INTEGER, elo_a INTEGER, elo_b INTEGER, delta_a INTEGER, delta_b INTEGER,
            rank_a TEXT, rank_b TEXT)""")
        existing.execute("INSERT INTO rating_matches(match_id,player_a,player_b,created_at) VALUES(?,?,?,?)",
                         ("f" * 32, 1, 2, 0))
    existing.close()
    migrated = store.database(legacy_path)
    assert migrated.execute("SELECT mode FROM rating_matches").fetchone() == ("ranked",)
    assert migrated.execute("PRAGMA integrity_check").fetchone() == ("ok",)
    migrated.close()
    conn = store.database(path)
    for name in ("match_player_a", "match_player_b"):
        assert store.handle(conn, {"action": "register", "username": name, "password": "password123!", "device": "d" * 32})["ok"]
    players = [r[0] for r in conn.execute("SELECT id FROM players ORDER BY id")]
    match_id = "a" * 32
    def request(action, **extra):
        return store.handle_match(conn, {"action": action, "match_id": match_id, **extra})
    assert not request("create", players=[players[0], players[0]])["ok"]
    assert not request("create", players=[players[0], 999999])["ok"]
    assert request("create", players=players)["ok"]
    assert request("create", players=players)["ok"]
    assert not request("create", players=list(reversed(players)))["ok"]
    assert not request("settle", winner=0)["ok"]
    assert request("start")["status"] == "playing"
    for winner in (-1, 2, True, "0"):
        assert not request("settle", winner=winner)["ok"]
    result = request("settle", winner=0)
    assert result["ratings"] == [1016, 984] and result["deltas"] == [16, -16]
    assert request("settle", winner=0) == result
    assert not request("settle", winner=1)["ok"]
    assert request("start")["status"] == "settled"
    assert request("cancel")["status"] == "settled"
    assert not store.handle(conn, {"action": "settle", "match_id": match_id, "winner": 0})["ok"]
    conn.close()
    conn = store.database(path)
    assert request("settle", winner=0) == result
    assert [r[0] for r in conn.execute("SELECT elo FROM players ORDER BY id")] == [1016, 984]
    match_id = "b" * 32
    conn.execute("UPDATE players SET elo=1400 WHERE id=?", (players[1],));conn.commit()
    assert request("create", players=players)["ok"] and request("start")["ok"]
    upset = request("settle", winner=0)
    assert upset["deltas"][0] > 16 and sum(upset["deltas"]) == 0
    match_id = "c" * 32
    assert request("create", players=players)["ok"] and request("cancel")["status"] == "cancelled"
    assert not request("settle", winner=1)["ok"]
    for index, player in enumerate(players):
        username = "match_player_a" if index == 0 else "match_player_b"
        login = store.handle(conn, {"action": "login", "username": username, "password": "password123!", "device": "d" * 32})
        assert login["elo"] == upset["ratings"][index]
        own = store.verify(conn, login["token"])
        assert own["player_id"] == player and own["elo"] == login["elo"]
        assert "ratings" not in own
    before = conn.execute("SELECT id,elo,rank_step,rank_stars,rank_streak FROM players ORDER BY id").fetchall()
    for index, winner in enumerate((0, 1)):
        match_id = str(index + 4) * 32
        assert request("create", players=players, mode="casual")["mode"] == "casual"
        assert not request("create", players=players, mode="ranked")["ok"]
        assert request("start")["status"] == "playing"
        # A settlement payload cannot change the mode saved at creation.
        casual = request("settle", winner=winner, mode="ranked")
        assert casual["status"] == "settled" and casual["winner"] == winner and not casual["rated"]
        assert casual["deltas"] == [0, 0] and casual["ranks"] == [{}, {}]
        assert conn.execute("SELECT id,elo,rank_step,rank_stars,rank_streak FROM players ORDER BY id").fetchall() == before
        assert conn.execute("SELECT rank_a,rank_b FROM rating_matches WHERE match_id=?", (match_id,)).fetchone() == (None, None)
        conn.close()
        conn = store.database(path)
        assert request("settle", winner=winner) == casual
        assert not request("settle", winner=1-winner)["ok"]
    for index, mode in enumerate(("exploration", "exploration_random")):
        match_id = str(index + 7) * 32
        assert request("create", players=players, mode=mode)["mode"] == mode
        assert not request("create", players=players, mode="casual")["ok"]
        assert request("start")["status"] == "playing"
        result = request("settle", winner=index, mode="ranked")
        assert result["mode"] == mode and not result["rated"] and result["deltas"] == [0, 0]
        assert conn.execute("SELECT id,elo,rank_step,rank_stars,rank_streak FROM players ORDER BY id").fetchall() == before
        conn.close()
        conn = store.database(path)
        assert request("settle", winner=index) == result
    match_id = "6" * 32
    assert not request("create", players=players, mode="invalid")["ok"]
    assert request("create", players=players, mode="casual")["ok"]
    assert request("cancel")["status"] == "cancelled"
    assert not request("settle", winner=0)["ok"]
    assert conn.execute("SELECT id,elo,rank_step,rank_stars,rank_streak FROM players ORDER BY id").fetchall() == before
    assert conn.execute("SELECT mode FROM rating_matches WHERE match_id=?", ("a" * 32,)).fetchone()[0] == "ranked"
    conn.close()
print("PASS: ranked settlement persists; casual and entertainment results preserve Elo, rank, stars and streak through retries and restart")
