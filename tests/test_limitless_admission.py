"""Quick import, stable account IDs and authenticated tournament admission."""
import hashlib
import io
import json
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store as accounts
import tournament_store as tournaments
import tournament_limitless as limitless
import tournament_limitless_web as web

EXTERNAL = "6aba47b9783097f8dcb72660"
URL = f"https://play.limitlesstcg.com/tournament/{EXTERNAL}/details"


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "players.db"
        self.conn = accounts.database(self.path)
        self.users = {}
        for i, username in enumerate(("bigcake", "alice", "bob", "heixingboshi"), 1):
            pid = self.conn.execute("INSERT INTO players(username,nickname,password_salt,password_hash,created_at) VALUES(?,?,X'',X'',0)", (username, username)).lastrowid
            token = str(i) * 64
            self.conn.execute("INSERT INTO sessions(player_id,platform,token_hash,device,issued_at) VALUES(?,'pc',?,'test',?)", (pid, hashlib.sha256(token.encode()).digest(), int(time.time())))
            self.users[username] = {"ok": True, "username": username, "player_id": pid, "token": token}
        self.conn.commit()
        self.data = limitless.normalize_snapshot(
            {"name": "好奇杯极彩十月月赛", "date": "2026-10-10T12:00:00Z", "finished": False,
             "phases": [{"phase": 1, "type": "SWISS", "rounds": 1, "mode": "BO3"}]},
            [{"player": "doctorblack", "name": "黑心 博士"}, {"player": "sss_naoh", "name": "七曜"}],
            [{"phase": 1, "round": 1, "table": 1, "player1": "doctorblack", "player2": "sss_naoh", "winner": None}])
        with patch.object(limitless, "request_sync", return_value="同步中"):
            answer = self.call("create_limitless", url=URL)
        self.tid = answer["tournament"]["id"]
        self.publish(self.data)

    def tearDown(self):
        with limitless._lock:
            limitless._jobs.clear()
        self.conn.close()
        self.tmp.cleanup()

    def call(self, action, user="bigcake", **kwargs):
        return tournaments.handle(self.conn, {"action": action, "id": getattr(self, "tid", 0), **kwargs}, self.users[user])

    def profile(self, user, value):
        return accounts.handle(self.conn, {"action": "limitless", "token": self.users[user]["token"], "limitless_id": value})

    def publish(self, data):
        generation = self.conn.execute("SELECT generation FROM tournament_limitless WHERE tournament_id=?", (self.tid,)).fetchone()[0]
        with limitless._lock:
            limitless._jobs[(limitless._scope(self.conn), self.tid, generation)] = (data, "", 120)
        limitless.tick(self.conn)

    def review(self, user="alice", **kwargs):
        return self.call("review_limitless_join", player_id=self.users[user]["player_id"], revision=1, approve=True, **kwargs)

    def test_import_metadata_permissions_and_retry_deduplication(self):
        view = self.call("detail")["tournament"]
        self.assertEqual((view["title"], view["start_at"], view["game_format"], view["phase"]), ("好奇杯极彩十月月赛", 1791633600, 3, "checkin"))
        self.assertEqual(self.call("create_limitless", url=URL)["tournament"]["id"], self.tid)
        self.assertFalse(self.call("create_limitless", "alice", url=URL)["ok"])
        self.assertFalse(self.call("create_limitless", url="https://localhost/private")["ok"])

    def test_account_normalization_validation_and_persistence(self):
        self.assertTrue(self.profile("alice", " DoctorBlack ")["ok"])
        self.assertEqual(accounts.verify(self.conn, self.users["alice"]["token"])["limitless_id"], "doctorblack")
        for invalid in ("黑心 博士", "https://example.com", "a" * 33, {}, None):
            self.assertFalse(self.profile("alice", invalid)["ok"])
        self.conn.close(); self.conn = accounts.database(self.path)
        self.assertEqual(accounts.verify(self.conn, self.users["alice"]["token"])["limitless_id"], "doctorblack")
        self.assertTrue(self.profile("alice", "")["ok"])

    def test_existing_relay_value_envelope_is_supported(self):
        result = accounts.handle(self.conn, {"action": "limitless", "token": self.users["alice"]["token"], "nickname": "DoctorBlack"})
        self.assertTrue(result["ok"])
        self.assertEqual(result["limitless_id"], "doctorblack")
        self.assertEqual(result["nickname"], "alice")
        result = accounts.handle(self.conn, {"action": "limitless", "token": self.users["alice"]["token"], "nickname": "ignored", "limitless_id": "sss_naoh"})
        self.assertEqual(result["limitless_id"], "sss_naoh")

    def test_gate_uses_server_account_not_submitted_id_or_display_name(self):
        self.assertFalse(self.call("join", "alice", limitless_id="doctorblack")["ok"])
        self.profile("alice", "outsider")
        self.assertFalse(self.call("detail", "alice")["tournament"]["limitless_admission"]["can_join"])
        self.assertFalse(self.call("join", "alice")["ok"])
        self.profile("alice", "doctorblack")
        response = self.call("join", "alice")
        self.assertTrue(response["ok"])
        self.assertFalse(response["tournament"]["joined"])
        self.assertEqual(response["tournament"]["member_count"], 0)
        self.assertEqual(response["join_requests"], {})
        self.assertFalse(self.call("checkin", "alice")["ok"])
        self.assertFalse(self.profile("alice", "sss_naoh")["ok"])
        self.call("join", "alice")
        self.assertEqual(self.call("detail")["join_requests"]["total"], 1)

    def test_review_owner_only_and_approval_is_atomic_and_idempotent(self):
        self.profile("alice", "doctorblack"); self.call("join", "alice")
        request = self.call("detail")["join_requests"]["entries"][0]
        self.assertEqual((request["external_player"], request["username"]), ("doctorblack", "alice"))
        for actor in ("alice", "heixingboshi"):
            self.assertFalse(self.call("review_limitless_join", actor, player_id=request["player_id"], revision=1, approve=True)["ok"])
        self.assertTrue(self.review()["ok"])
        self.assertFalse(self.review()["ok"])
        state = self.call("detail", "alice")["tournament"]
        self.assertTrue(state["joined"] and state["checked_in"] and state["in_roster"])
        self.assertEqual(state["roster_count"], 1)
        self.assertEqual(limitless._mapped(self.conn, self.tid), {"doctorblack": self.users["alice"]["player_id"]})
        self.assertFalse(self.call("map_limitless", mapping="doctorblack=bob")["ok"])
        self.assertFalse(self.call("unlink_limitless")["ok"])
        self.assertFalse(self.profile("alice", "")["ok"])

    def test_rejection_withdrawal_revision_conflicts_and_duplicate_identity(self):
        self.profile("alice", "doctorblack"); self.profile("bob", "doctorblack")
        self.call("join", "alice"); self.call("join", "bob")
        self.assertTrue(self.review("bob")["ok"])
        self.assertFalse(self.review()["ok"])
        self.assertTrue(self.call("review_limitless_join", player_id=self.users["alice"]["player_id"], revision=1, approve=False)["ok"])
        self.profile("alice", "sss_naoh"); self.call("join", "alice")
        self.assertFalse(self.review()["ok"])
        self.assertTrue(self.call("leave", "alice")["ok"])
        self.assertTrue(self.profile("alice", "")["ok"])
        self.assertEqual(self.call("detail")["tournament"]["roster_count"], 1)

    def test_locked_tournament_accepts_verified_late_entrants_and_can_start(self):
        self.call("close_checkin")
        for name, external in (("alice", "doctorblack"), ("bob", "sss_naoh")):
            self.profile(name, external)
            self.assertTrue(self.call("join", name)["ok"])
            self.assertTrue(self.review(name)["ok"])
        self.assertTrue(self.call("start_round", expected_round=0)["ok"])
        self.assertFalse(self.call("complete_limitless", finished=True)["ok"])

    def test_stale_sync_and_missing_source_player_block_approval(self):
        self.profile("alice", "doctorblack"); self.call("join", "alice")
        self.conn.execute("UPDATE tournament_limitless SET synced_at=1"); self.conn.commit()
        self.assertFalse(self.review()["ok"])
        self.assertEqual(self.call("detail")["tournament"]["roster_count"], 0)
        removed = {**self.data, "standings": [], "pairings": []}
        self.publish(removed)
        self.assertFalse(self.review()["ok"])

    def test_upcoming_import_retains_normal_registration(self):
        upcoming = {**self.data, "start_at": int(time.time()) + 3600, "started": False, "pairings": []}
        self.conn.execute("UPDATE tournament_limitless SET import_pending=1"); self.conn.commit(); self.publish(upcoming)
        self.assertTrue(self.call("join", "alice")["tournament"]["joined"])
        self.assertEqual(self.call("detail")["join_requests"]["total"], 0)


class LivePageTests(unittest.TestCase):
    def test_live_api_fallback_and_stable_ids(self):
        details = web.Document('''<div class="tournament-header"><div class="name">好奇杯极彩十月月赛</div></div>
            <table class="basics"><tr><td data-time="1791633600000"></td></tr></table>
            <div class="description"><p>比赛说明</p></div><div class="structure"><div class="phase">
            <div class="rounds">5 Swiss Rounds - BO3</div></div><div class="phase"><div class="rounds">1 Single Elimination Round - BO3</div></div></div>''').root
        raw = web.metadata(details)
        roster_doc = web.Document(f'''<div class="standings ongoing"><table><tr data-placing="17"><td>17</td>
            <td><a href="/tournament/{EXTERNAL}/player/doctorblack">黑心 博士</a></td><td>1 - 4 - 0</td></tr></table></div>''').root
        roster = web.players(roster_doc, EXTERNAL)
        pairing_doc = web.Document(f'''<table data-tournament="{EXTERNAL}" data-round="6">
            <tr data-match="m" data-completed="0" data-winner="0"><td>7</td><td class="player" data-id="doctorblack"></td><td class="player" data-id="sss_naoh"></td></tr></table>''').root
        number, pairings = web.matches(pairing_doc, EXTERNAL, raw["phases"])
        self.assertEqual((number, pairings[0]["phase"], pairings[0]["round"], pairings[0]["winner"]), (6, 2, 1, None))
        with patch.object(limitless, "_fetch", side_effect=limitless.LiveTournament("live")), patch.object(web, "fetch", return_value=(raw, roster, pairings)):
            parsed = limitless.snapshot(EXTERNAL)
        self.assertEqual(parsed["standings"][0]["player"], "doctorblack")
        self.assertEqual(parsed["standings"][0]["name"], "黑心 博士")
        self.assertFalse(parsed["finished"])
        self.assertTrue(parsed["started"])

    def test_unfinished_api_detection_and_unrecognized_pages_fail_closed(self):
        response = HTTPError("", 400, "Bad Request", {}, io.BytesIO(b'"Tournament is not finished yet."'))
        with patch.object(limitless, "build_opener") as opener:
            opener.return_value.open.side_effect = response
            with self.assertRaises(limitless.LiveTournament):
                limitless._fetch(EXTERNAL, "details")
        with self.assertRaises(ValueError):
            web.metadata(web.Document("<h1>Login required</h1>").root)


if __name__ == "__main__":
    unittest.main()
