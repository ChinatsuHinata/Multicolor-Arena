"""Current legal deck fixtures and the real competition admission flow."""
import json
from pathlib import Path
import tournament_store

ROOT = Path(__file__).resolve().parents[2]


def deck(game_format=2, index=0):
    if game_format in (4, 5):
        return json.loads((ROOT / "relay/deck_plaza_catalogue.json").read_text(encoding="utf-8"))["fixed_decks"][str(game_format)]
    value = json.loads((ROOT / "data/test_precons.json").read_text(encoding="utf-8"))["decks"][index]
    return {key: item for key, item in value.items() if key in ("id", "name", "leader", "main", "side", "rule_set", "art_overrides")}


def admit(conn, tid, players):
    config = tournament_store.config(conn, tid)
    signatures = []
    for player in players:
        account = {"ok": True, "player_id": player, "username": conn.execute("SELECT username FROM players WHERE id=?", (player,)).fetchone()[0]}
        value = deck(config["game_format"])
        if tournament_store.decklist_view(conn, tid, player)["required"]:
            answer = tournament_store.handle(conn, {"action": "submit_decklist", "id": tid, "round_number": config["round_number"], "deck": value}, account)
            assert answer["ok"], answer
        ticket = conn.execute("SELECT match_id FROM tournament_pairings WHERE tournament_id=? AND round_number=? AND (player_a=? OR player_b=?)", (tid, config["round_number"], player, player)).fetchone()[0]
        answer = tournament_store.handle_game(conn, {"action": "lookup", "match_id": ticket, "player_id": player, "deck": value})
        assert answer["ok"], answer
        signatures.append(answer["deck_signature"])
    return signatures
