import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store as accounts
import cloud_deck_store as cloud


class CloudDeckTests(unittest.TestCase):
    def setUp(self):
        scratch = Path(__file__).resolve().parents[1] / "work/cloud-deck-store-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch)
        self.path = Path(self.temp.name) / "players.sqlite3"
        self.conn = accounts.database(self.path)
        self.players = []
        for username in ("cloud_player", "other_player"):
            payload = {"username": username, "password": "password123!", "device": "a" * 32}
            self.assertTrue(accounts.handle(self.conn, dict(payload, action="register"))["ok"])
            login = accounts.handle(self.conn, dict(payload, action="login"))
            self.players.append(accounts.verify(self.conn, login["token"]))
        self.code = "MA1:" + json.dumps(["原名称（副本）", "70", [["100", 4]], [], "official", {"70": "tts_151600"}], ensure_ascii=False)

    def tearDown(self):
        self.conn.close()
        self.temp.cleanup()

    def request(self, action="list", account=None, **fields):
        return cloud.handle(self.conn, dict(action=action, **fields), account or self.players[0])

    def save(self, slot=0, revision=0, **fields):
        return self.request("save", slot=slot, revision=revision, deck_code=self.code, **fields)

    def test_ten_slots_persist_and_accounts_are_isolated(self):
        for slot in range(1, 11):
            answer = self.save()
            self.assertTrue(answer["ok"], answer)
            self.assertEqual(answer["slot"], slot)
        self.assertFalse(self.save()["ok"])
        self.assertEqual(self.request(account=self.players[1])["decks"], [])
        self.conn.close()
        self.conn = accounts.database(self.path)
        decks = self.request()["decks"]
        self.assertEqual(len(decks), 10)
        self.assertEqual(decks[0]["deck_code"], self.code)

    def test_stale_edits_deletes_and_reused_slots(self):
        original = self.save()["decks"][0]
        updated = self.save(1, original["revision"])
        self.assertTrue(updated["ok"])
        self.assertEqual(updated["decks"][0]["identity"], original["identity"])
        self.assertTrue(self.save(1, original["revision"])["conflict"])
        self.assertTrue(self.request("delete", slot=1, revision=original["revision"])["conflict"])
        revision = updated["decks"][0]["revision"]
        self.assertTrue(self.request("delete", slot=1, revision=revision)["ok"])
        reused = self.save()["decks"][0]
        self.assertGreater(reused["revision"], revision)
        self.assertNotEqual(reused["identity"], original["identity"])
        self.assertTrue(self.save(1, revision)["conflict"])
        self.assertTrue(self.save(1, 0, account=self.players[1])["ok"])
        self.assertEqual(self.request()["decks"][0], reused)

    def test_invalid_payloads_and_authentication_do_not_change_slots(self):
        self.assertFalse(cloud.handle(self.conn, {"action": "list"}, {"ok": False})["ok"])
        for fields in ({"slot": 11}, {"slot": -1}, {"slot": True}, {"revision": -1},
                       {"revision": "0"}, {"deck_code": "invalid"}, {"username": "other_player"}):
            payload = dict(action="save", slot=0, revision=0, deck_code=self.code)
            payload.update(fields)
            self.assertFalse(cloud.handle(self.conn, payload, self.players[0])["ok"])
        self.assertEqual(self.request()["decks"], [])

    def test_godot_json_numeric_round_trip(self):
        answer = self.save(0.0, 0.0)
        self.assertTrue(answer["ok"], answer)
        self.assertTrue(self.save(1.0, float(answer["decks"][0]["revision"]))["ok"])

    def test_retired_rule_migrates_without_losing_cards_or_art(self):
        parts = json.loads(self.code[4:])
        parts[4] = "official_spx"
        result = self.request("save", slot=0, revision=0, deck_code="MA1:" + json.dumps(parts, ensure_ascii=False))
        self.assertTrue(result["ok"], result)
        saved = cloud.codes.deck_parts(result["decks"][0]["deck_code"])
        self.assertEqual(saved[4], "unrestricted")
        self.assertEqual(saved[1:4], parts[1:4])
        self.assertEqual(saved[5], parts[5])


if __name__ == "__main__":
    unittest.main()
