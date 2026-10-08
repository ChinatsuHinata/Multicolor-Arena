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
    conn.close()
print("PASS: rated matches persist, use expected Elo and cannot be settled through the account API")
