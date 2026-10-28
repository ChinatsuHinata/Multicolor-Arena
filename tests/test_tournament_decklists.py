"""Server-owned pre-match lists, rule compliance, isolation and admission."""
import copy
import json
import sqlite3
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store as accounts
import tournament_store as store
import deck_plaza_store
from support.tournament_decks import deck


class DecklistTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = Path(self.directory.name) / "players.db"
        self.conn = accounts.database(self.path)
        self.users = {}
        for name in ("bigcake", "alice", "bob", "carol", "dave", "outsider"):
            player = self.conn.execute("INSERT INTO players(username,nickname,password_salt,password_hash,created_at) VALUES(?,?,X'',X'',0)", (name, name)).lastrowid
            self.users[name] = {"ok": True, "username": name, "player_id": player}
        self.conn.commit()
        clock = patch("tournament_store.time.time", return_value=int(time.time()))
        self.clock = clock.start()
        self.addCleanup(clock.stop)
        self.tid = self.call("create", title="牌表测试", swiss_rounds=2, start_at=int(time.time()) + 3600)["tournament"]["id"]
        for user in ("alice", "bob", "carol", "dave"):
            self.assertTrue(self.call("join", user)["ok"])
        self.deadline = int(time.time()) + 3600
        self.assertTrue(self.rules()["ok"])

    def tearDown(self):
        self.conn.close()
        self.directory.cleanup()

    def call(self, action, user="bigcake", **data):
        return store.handle(self.conn, {"action": action, "id": getattr(self, "tid", 0), **data}, self.users[user])

    def submit(self, value=None, user="alice", number=1):
        return self.call("submit_decklist", user, round_number=number, deck=deck() if value is None else value)

    def rules(self, user="bigcake", number=1, fixed=True, deadline=None):
        return self.call("configure_decklist", user, round_number=number, fixed_deck=fixed,
                         deadline_at=self.deadline if deadline is None else deadline)

    def close_lists(self):
        self.clock.return_value = self.deadline

    def admit_pair(self):
        for player in self.pair[1:]:
            user = next(name for name, account in self.users.items() if account["player_id"] == player)
            self.assertTrue(self.submit(user=user)["ok"])
        self.close_lists()
        return [store.handle_game(self.conn, {"action": "lookup", "match_id": self.pair[0], "player_id": player, "deck": deck()})["deck_signature"] for player in self.pair[1:]]

    def start(self):
        with self.conn:
            self.conn.execute("UPDATE tournaments SET start_at=? WHERE id=?", (int(time.time()), self.tid))
        for user in ("alice", "bob", "carol", "dave"):
            self.assertTrue(self.call("checkin", user)["ok"])
        self.assertTrue(self.call("close_checkin")["ok"])
        self.assertTrue(self.call("start_round", expected_round=0)["ok"])
        self.pair = self.conn.execute("SELECT match_id,player_a,player_b FROM tournament_pairings WHERE tournament_id=? AND (player_a=? OR player_b=?)", (self.tid, self.users["alice"]["player_id"], self.users["alice"]["player_id"])).fetchone()

    def lookup(self, value=None, user="alice"):
        return store.handle_game(self.conn, {"action": "lookup", "match_id": self.pair[0], "player_id": self.users[user]["player_id"], "deck": deck() if value is None else value})

    def test_replacement_is_persistent_and_private(self):
        self.assertTrue(self.submit()["ok"])
        self.assertTrue(self.submit(deck(index=1))["ok"])
        self.assertTrue(self.submit()["ok"])
        self.assertTrue(self.submit(deck(index=1))["decklist"]["can_submit"])
        self.conn.close(); self.conn = accounts.database(self.path)
        self.assertEqual(self.call("detail", "alice")["decklist"]["deck"], deck(index=1))
        for user in ("bob", "bigcake", "outsider"):
            answer = self.call("detail", user)
            self.assertEqual(answer["decklist"]["deck"], {})
            self.assertNotIn('"main"', json.dumps(answer["pairings"]))
        self.assertFalse(self.submit(user="outsider")["ok"])
        self.assertFalse(self.submit(number=2)["ok"])

    def test_actual_deck_validation_and_zone_lock(self):
        self.start()
        self.assertFalse(self.lookup()["ok"])
        self.assertTrue(self.submit()["ok"])
        self.assertFalse(self.lookup()["ok"], "entry waits for submission deadline")
        self.close_lists()
        self.assertTrue(self.lookup()["ok"])
        changed = deck(); changed["side"] = [deck(index=1)["main"][0]]
        self.assertFalse(self.lookup(changed)["ok"])
        self.assertFalse(self.lookup(deck(index=1))["ok"])
        self.assertFalse(self.lookup(user="outsider")["ok"])
        for raw in (None, [], {}, {"deck_hash": "a" * 64}):
            answer = store.handle_game(self.conn, {"action": "lookup", "match_id": self.pair[0], "player_id": self.users["alice"]["player_id"], "deck": raw})
            self.assertFalse(answer["ok"])

    def test_sort_name_id_and_art_do_not_change_cards(self):
        self.start(); self.assertTrue(self.submit()["ok"])
        self.close_lists()
        changed = deck(); changed["main"].reverse(); changed["id"] = "different-local-id"; changed["name"] = "另一设备的名称"
        self.assertTrue(self.lookup(changed)["ok"])
        cards = deck_plaza_store.catalogue()
        for card in [changed["leader"], *changed["main"]]:
            if cards[card]["canonical"] == card and cards[card]["arts"]:
                changed["art_overrides"] = {card: cards[card]["arts"][-1]}
                break
        self.assertTrue(self.lookup(changed)["ok"])
        self.assertTrue(self.submit(changed)["ok"])
        self.assertEqual(self.call("detail", "alice")["decklist"]["deck"], deck())

    def test_same_total_pool_cannot_be_pre_sideboarded_at_entry(self):
        self.start()
        value = deck(); cards = deck_plaza_store.catalogue()
        names = {cards[card]["name_key"] for card in [value["leader"], *value["main"]]}
        extra = next(card for card, info in cards.items() if info["match_allowed"] and info["name_key"] not in names and not info["leader"])
        value["side"] = [extra]
        self.assertTrue(self.submit(value)["ok"])
        self.close_lists()
        changed = copy.deepcopy(value)
        changed["main"][0], changed["side"][0] = changed["side"][0], changed["main"][0]
        self.assertFalse(self.lookup(changed)["ok"])
        self.assertTrue(self.lookup(value)["ok"])

    def test_legality_rejects_malformed_incomplete_unavailable_and_over_limit(self):
        cards = deck_plaza_store.catalogue()
        cases = [None, [], {}, {**deck(), "extra": "asset"}, {**deck(), "leader": 1}, {**deck(), "rule_set": "mod"},
                 {**deck(), "main": deck()["main"][:-1]}, {**deck(), "main": ["unknown"] * 50},
                 {**deck(), "main": [True] * 50}, {**deck(), "side": [deck()["main"][0]] * 11},
                 {**deck(), "side": [deck()["leader"]]}, {**deck(), "art_overrides": {"unknown": "art"}}]
        for maximum in (1, 2, 4):
            card = next(key for key, value in cards.items() if value["match_allowed"] and value["match_limit"] == maximum and not value["leader"])
            invalid = deck(); invalid["main"][:maximum + 1] = [card] * (maximum + 1); cases.append(invalid)
            invalid = deck(); invalid["main"][0] = card; invalid["side"] = [card] * maximum; cases.append(invalid)
        unavailable = next(key for key, value in cards.items() if not value["match_allowed"])
        cases.append({**deck(), "side": [unavailable]})
        for invalid in cases:
            with self.subTest(value=str(invalid)[:100]):
                self.assertFalse(self.call("submit_decklist", "alice", round_number=1, deck=invalid)["ok"])
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM tournament_decklists").fetchone()[0], 0)

    def test_claim_requires_both_validated_lists_and_cancel_preserves_lock(self):
        self.start()
        request = {"action": "create", "match_id": self.pair[0], "players": list(self.pair[1:]), "mode": "casual"}
        self.assertFalse(accounts.handle_match(self.conn, request)["ok"])
        self.assertFalse(accounts.handle_match(self.conn, {**request, "deck_signatures": ["a" * 64] * 2})["ok"])
        signatures = self.admit_pair()
        self.assertTrue(accounts.handle_match(self.conn, {**request, "deck_signatures": signatures})["ok"])
        self.assertTrue(accounts.handle_match(self.conn, {"action": "cancel", "match_id": self.pair[0]})["ok"])
        self.assertFalse(self.submit(deck(index=1))["ok"])
        self.assertFalse(self.lookup()["ok"], "old ticket is retired")
        self.pair = self.conn.execute("SELECT match_id,player_a,player_b FROM tournament_pairings WHERE tournament_id=? AND (player_a=? OR player_b=?)", (self.tid, self.users["alice"]["player_id"], self.users["alice"]["player_id"])).fetchone()
        self.assertTrue(self.lookup()["ok"])

    def test_next_round_requires_new_submission_and_stale_round_cannot_write(self):
        self.start(); self.admit_pair()
        with self.conn:
            self.conn.execute("UPDATE tournament_pairings SET result=0 WHERE tournament_id=?", (self.tid,))
        self.assertTrue(self.call("start_round", expected_round=1)["ok"])
        self.assertFalse(self.call("detail", "alice")["decklist"]["submitted"])
        self.assertFalse(self.call("detail", "alice")["decklist"]["required"], "new rounds default to free deck selection")
        self.assertFalse(self.submit()["ok"])
        self.deadline += 3600
        self.assertTrue(self.rules(number=2)["ok"])
        self.assertTrue(self.submit(deck(index=1), number=2)["ok"])
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM tournament_decklists WHERE player_id=?", (self.users["alice"]["player_id"],)).fetchone()[0], 2)

    def test_fixed_modes_are_checked_rejoining_allows_edits_and_deletion_clears_lists(self):
        for mode in (4, 5):
            self.assertEqual(len(store.checked_deck(deck(mode), mode)), 64)
            invalid = deck(mode); invalid["main"][0] = deck()["main"][0]
            with self.assertRaises(ValueError):store.checked_deck(invalid, mode)
        self.assertTrue(self.submit()["ok"])
        self.assertTrue(self.call("leave", "alice")["ok"])
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM tournament_decklists").fetchone()[0], 1)
        self.assertTrue(self.call("join", "alice")["ok"])
        self.assertTrue(self.submit(deck(index=1))["ok"])
        self.assertTrue(self.submit()["ok"])
        self.assertTrue(self.call("delete")["ok"])
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM tournament_decklists").fetchone()[0], 0)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM tournament_decklist_rules").fetchone()[0], 0)

    def test_concurrent_replacements_are_atomic(self):
        barrier = threading.Barrier(2); results = []
        def submit(index):
            conn = sqlite3.connect(self.path, timeout=10)
            try:
                barrier.wait()
                results.append(store.handle(conn, {"action": "submit_decklist", "id": self.tid, "round_number": 1, "deck": deck(index=index)}, self.users["alice"]))
            finally:conn.close()
        threads = [threading.Thread(target=submit, args=(i,)) for i in range(2)]
        for thread in threads:thread.start()
        for thread in threads:thread.join(15)
        self.assertEqual(sum(result["ok"] for result in results), 2)
        self.assertEqual(len(results), 2)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM tournament_decklists").fetchone()[0], 1)
        stored, signature = self.conn.execute("SELECT deck_json,signature FROM tournament_decklists").fetchone()
        self.assertIn(json.loads(stored), [deck(), deck(index=1)])
        self.assertEqual(signature, store.checked_deck(json.loads(stored), 2))

    def test_deadline_boundary_blocks_initial_and_replacement_submissions(self):
        self.start()
        self.clock.return_value = self.deadline - 1
        self.assertTrue(self.submit()["ok"])
        replacement = self.submit(deck(index=1))
        self.assertTrue(replacement["ok"])
        self.assertFalse(replacement["decklist"]["can_enter"])
        self.close_lists()
        before = self.conn.execute("SELECT * FROM tournament_decklists").fetchall()
        self.assertFalse(self.submit()["ok"])
        self.assertFalse(self.submit(user="bob")["ok"])
        self.assertTrue(self.submit(deck(index=1))["ok"], "identical retry is harmless")
        self.assertEqual(self.conn.execute("SELECT * FROM tournament_decklists").fetchall(), before)
        view = self.call("detail", "alice")["decklist"]
        self.assertTrue(view["closed"] and view["can_enter"])
        self.assertFalse(view["can_submit"])
        self.assertFalse(self.rules(fixed=False)["ok"])
        self.assertFalse(self.rules(deadline=self.deadline + 3600)["ok"])
        self.assertTrue(self.lookup(deck(index=1))["ok"])
        self.assertFalse(self.lookup()["ok"])
        self.conn.close(); self.conn = accounts.database(self.path)
        self.assertFalse(self.submit()["ok"], "restart preserves deadline")

    def test_optional_round_skips_submission_but_still_checks_actual_cards(self):
        self.assertTrue(self.rules(fixed=False)["ok"])
        self.assertFalse(self.submit()["ok"])
        self.start()
        view = self.call("detail", "alice")["decklist"]
        self.assertFalse(view["required"])
        self.assertTrue(view["can_enter"])
        self.assertTrue(self.lookup()["ok"])
        self.assertTrue(self.lookup(deck(index=1))["ok"])
        self.assertFalse(self.lookup({})["ok"])
        signatures = [store.handle_game(self.conn, {"action": "lookup", "match_id": self.pair[0], "player_id": player, "deck": deck(index=index)})["deck_signature"] for index, player in enumerate(self.pair[1:])]
        self.assertTrue(accounts.handle_match(self.conn, {"action": "create", "match_id": self.pair[0], "players": list(self.pair[1:]), "mode": "casual", "deck_signatures": signatures})["ok"])
        self.assertFalse(self.rules()["ok"], "cannot impose new rules after entry")
        self.assertTrue(accounts.handle_match(self.conn, {"action": "cancel", "match_id": self.pair[0]})["ok"])
        self.assertFalse(self.rules()["ok"], "cancellation cannot reopen round rules")

    def test_validation_cannot_write_past_deadline(self):
        self.assertTrue(self.submit()["ok"])
        checked = store.checked_deck
        def slow_check(value, game_format):
            signature = checked(value, game_format)
            self.close_lists()
            return signature
        self.clock.return_value = self.deadline - 1
        with patch.object(store, "checked_deck", side_effect=slow_check):
            self.assertFalse(self.submit(deck(index=1))["ok"])
        self.assertEqual(self.call("detail", "alice")["decklist"]["deck"], deck())

    def test_rule_permissions_validation_and_future_round_isolation(self):
        self.assertFalse(self.rules(user="alice", fixed=False)["ok"])
        for values in ({"fixed":1}, {"deadline":True}, {"deadline":int(time.time())}, {"number":2}, {"number":0}):
            self.assertFalse(self.rules(**values)["ok"])
        self.start()
        self.assertTrue(self.rules(number=2, deadline=self.deadline+3600)["ok"])
        self.assertEqual(self.call("detail", "alice")["decklist"]["deadline_at"], self.deadline)
        self.assertTrue(self.submit()["ok"])
        self.assertFalse(self.submit({**deck(), "main": []})["ok"])
        self.assertEqual(self.call("detail", "alice")["decklist"]["deck"], deck())
        self.assertTrue(self.rules(fixed=False)["ok"])
        self.assertFalse(self.call("detail", "alice")["decklist"]["required"])
        self.assertTrue(store.decklist_rule(self.conn, self.tid, 2)["fixed_deck"])

    def test_claim_rechecks_latest_list_and_deadline(self):
        self.start()
        for player in self.pair[1:]:
            user = next(name for name, account in self.users.items() if account["player_id"] == player)
            self.assertTrue(self.submit(user=user)["ok"])
        old = store.checked_deck(deck(), 2)
        request = {"action":"claim", "match_id":self.pair[0], "players":list(self.pair[1:]), "deck_signatures":[old, old]}
        self.assertFalse(store.handle_game(self.conn, request)["ok"])
        self.assertTrue(self.submit(deck(index=1))["ok"])
        self.close_lists()
        self.assertFalse(store.handle_game(self.conn, request)["ok"])
        request["deck_signatures"][self.pair[1:].index(self.users["alice"]["player_id"])] = store.checked_deck(deck(index=1), 2)
        self.assertTrue(store.handle_game(self.conn, request)["ok"])


if __name__ == "__main__":
    unittest.main()
