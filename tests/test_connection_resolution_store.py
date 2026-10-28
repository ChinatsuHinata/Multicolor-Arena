"""Attribution and ratings must be committed once, with their original evidence."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store


class ResolutionStoreTests(unittest.TestCase):
    def setUp(self):
        scratch = Path(__file__).resolve().parents[1] / "work" / "connection-resolution"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="TEST_ONLY_", dir=scratch)
        self.path = Path(self.temp.name) / "players.sqlite3"
        self.conn = account_store.database(self.path)
        for index in range(2):
            result = account_store.handle(self.conn, {"action": "register", "username": f"TEST_ONLY_resolution_{index}",
                                                      "password": "TestOnlyPassword!", "device": "d" * 32})
            self.assertTrue(result["ok"], result)
        self.players = [row[0] for row in self.conn.execute("SELECT id FROM players ORDER BY id")]
        self.match_id = "a" * 32
        self.assertTrue(account_store.handle_match(self.conn, {"action": "create", "match_id": self.match_id,
                                                              "players": self.players})["ok"])

    def tearDown(self):
        self.conn.close()
        self.temp.cleanup()

    def test_timeout_decision_is_durable_and_idempotent(self):
        account_store.handle_match(self.conn, {"action": "start", "match_id": self.match_id})
        resolution = {"reason": "player_link_timeout", "intent": "undetermined",
                      "evidence": [{"player_id": self.players[1], "seat": 2, "cause": "probe_timeout"}]}
        payload = {"action": "settle", "match_id": self.match_id, "winner": 0, "resolution": resolution}
        result = account_store.handle_match(self.conn, payload)
        self.assertTrue(result["ok"])
        ratings = result["ratings"]
        self.conn.close()
        self.conn = account_store.database(self.path)
        duplicate = account_store.handle_match(self.conn, {**payload, "resolution": {"reason": "forged_retry"}})
        self.assertEqual(duplicate["ratings"], ratings)
        row = self.conn.execute("SELECT status,winner,detail FROM match_resolutions").fetchone()
        self.assertEqual(row[:2], ("settled", 0))
        self.assertEqual(json.loads(row[2]), resolution)
        self.assertFalse(account_store.handle_match(self.conn, {**payload, "winner": 1})["ok"])

    def test_unknown_side_cancels_without_rating_or_blame(self):
        ratings = self.conn.execute("SELECT elo FROM players ORDER BY id").fetchall()
        result = account_store.handle_match(self.conn, {"action": "cancel", "match_id": self.match_id,
                                                       "resolution": {"reason": "both_links_unavailable"}})
        self.assertTrue(result["ok"])
        self.assertEqual(self.conn.execute("SELECT elo FROM players ORDER BY id").fetchall(), ratings)
        status, detail = self.conn.execute("SELECT status,detail FROM match_resolutions").fetchone()
        self.assertEqual(status, "cancelled")
        self.assertEqual(json.loads(detail)["reason"], "both_links_unavailable")
        self.assertFalse(account_store.handle(self.conn, {"action": "settle", "match_id": self.match_id, "winner": 0})["ok"])


if __name__ == "__main__":
    unittest.main()
