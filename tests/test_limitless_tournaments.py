"""Limitless authority, asynchronous mirrors, source identity and round gates."""
import copy
import io
import json
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store
import tournament_store as store
import tournament_limitless as limitless
from tournament_pairing import knockout_pairs

EXTERNAL = "636bf4efa527ff22cbbd82ae"


def source():
    return {"title": "来源比赛", "phases": [{"phase": 1, "type": "SWISS", "mode": "BO3", "rounds": 2}],
            "standings": [{"player": p, "name": p.upper(), "placing": i, "wins": 1, "ties": 0, "losses": 0, "drop": False}
                          for i, p in enumerate(("alice", "bob", "carol", "dave"), 1)],
            "pairings": [{"phase": 1, "round": 1, "table": t, "match": "", "players": [a, b], "names": [a, b], "result": "pending"}
                         for t, a, b in ((7, "alice", "bob"), (9, "carol", "dave"))]}


class LimitlessTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.conn = account_store.database(Path(self.directory.name) / "players.db")
        self.accounts = {}
        for name in ("bigcake", "alice", "bob", "carol", "dave"):
            pid = self.conn.execute("INSERT INTO players(username,nickname,password_salt,password_hash,created_at) VALUES(?,?,X'',X'',0)", (name, name)).lastrowid
            self.accounts[name] = {"ok": True, "username": name, "player_id": pid}
        self.conn.commit()
        answer = store.handle(self.conn, {"action": "create", "title": "同步比赛", "start_at": int(time.time()) + 3600}, self.accounts["bigcake"])
        self.tid = answer["tournament"]["id"]
        self.data = source()
        self.bind()

    def tearDown(self):
        with limitless._lock:
            limitless._jobs.clear()
        self.conn.close()
        self.directory.cleanup()

    def call(self, action, user="bigcake", **kwargs):
        return store.handle(self.conn, {"action": action, "id": self.tid, **kwargs}, self.accounts[user])

    def bind(self):
        with self.conn:
            self.conn.execute("INSERT OR REPLACE INTO tournament_limitless(tournament_id,external_id,generation,snapshot_json,synced_at) VALUES(?,?,'test',?,?)",
                              (self.tid, EXTERNAL, json.dumps(self.data), int(time.time())))

    def roster(self):
        mapping = "\n".join(f"{name}={name}" for name in self.accounts if name != "bigcake")
        self.assertTrue(self.call("map_limitless", mapping=mapping)["ok"])
        with self.conn:
            self.conn.execute("UPDATE tournaments SET phase='locked' WHERE id=?", (self.tid,))
            self.conn.executemany("INSERT INTO tournament_members(tournament_id,player_id,joined_at,in_roster,seed) VALUES(?,?,0,1,?)",
                                  ((self.tid, a["player_id"], i) for i, (name, a) in enumerate(self.accounts.items()) if name != "bigcake"))

    def publish(self, data):
        key = (limitless._scope(self.conn), self.tid, "test")
        with limitless._lock:
            limitless._jobs[key] = (data, "", 120)
        limitless.tick(self.conn)

    def next_round(self):
        self.data["pairings"][0]["result"] = "a"
        self.data["pairings"][1]["result"] = "tie"
        self.data["pairings"].extend([
            {"phase": 1, "round": 2, "table": 3, "match": "", "players": ["dave", "alice"], "names": ["dave", "alice"], "result": "pending"},
            {"phase": 1, "round": 2, "table": 5, "match": "", "players": ["bob", "carol"], "names": ["bob", "carol"], "result": "pending"}])

    def test_source_rounds_require_mapping_roster_and_exact_source_results(self):
        self.conn.execute("UPDATE tournaments SET phase='locked' WHERE id=?", (self.tid,)); self.conn.commit()
        self.assertFalse(self.call("start_round", expected_round=0)["ok"])
        self.roster()
        first = self.call("start_round", expected_round=0)
        self.assertTrue(first["ok"], first)
        self.assertEqual([p["table"] for p in first["pairings"]], [7, 9])
        self.assertEqual(first["pairings"][0]["names"], ["alice", "bob"])
        self.assertFalse(self.call("start_round", expected_round=1)["ok"])
        self.next_round()
        # Publishing a next round alone cannot bypass missing results from the prior round.
        self.data["pairings"][0]["result"] = "pending"
        self.publish(self.data)
        self.assertFalse(self.call("start_round", expected_round=1)["ok"])
        self.data["pairings"][0]["result"] = "b"
        self.publish(self.data)
        second = self.call("start_round", expected_round=1)
        self.assertTrue(second["ok"], second)
        self.assertEqual([p["names"] for p in second["pairings"]], [["dave", "alice"], ["bob", "carol"]])
        history = self.call("detail", pairing_round=1)
        self.assertEqual([p["result"] for p in history["pairings"]], [1, -1])
        self.assertEqual(history["tournament"]["round_number"], 2)
        self.assertFalse(self.call("start_round", expected_round=1)["ok"])
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM tournament_rounds WHERE tournament_id=?", (self.tid,)).fetchone()[0], 2)

    def test_game_result_waits_for_limitless_and_manual_override_is_blocked(self):
        self.roster(); first = self.call("start_round", expected_round=0)
        pair = first["pairings"][0]
        for action in ("report_result", "confirm_result", "judge_result"):
            self.assertFalse(self.call(action, pairing_id=pair["id"], revision=0, result=0, scores=[2, 0])["ok"])
        players = [self.accounts[n]["player_id"] for n in ("alice", "bob")]
        ticket = self.conn.execute("SELECT match_id FROM tournament_pairings WHERE id=?", (pair["id"],)).fetchone()[0]
        self.assertTrue(store.handle_game(self.conn, {"action": "claim", "match_id": ticket, "players": players})["ok"])
        self.assertTrue(store.handle_game(self.conn, {"action": "settle", "match_id": ticket, "winner": 0, "scores": [2, 0]})["ok"])
        result = self.conn.execute("SELECT result,source FROM tournament_pairings WHERE id=?", (pair["id"],)).fetchone()
        self.assertEqual(result, (None, "awaiting_limitless"))
        self.assertFalse(store.handle_game(self.conn, {"action": "lookup", "match_id": ticket, "player_id": players[0]})["ok"])
        self.data["pairings"][0]["result"] = "b"; self.publish(self.data)
        self.assertEqual(self.conn.execute("SELECT result,score_a FROM tournament_pairings WHERE id=?", (pair["id"],)).fetchone(), (1, None))

    def test_changed_source_pairing_and_failed_sync_preserve_last_good_snapshot(self):
        self.roster(); self.call("start_round", expected_round=0)
        changed = copy.deepcopy(self.data); changed["pairings"][0]["players"].reverse()
        self.publish(changed)
        mirror = limitless.view(self.conn, self.tid, {})
        self.assertIn("签表已更改", mirror["error"])
        self.assertEqual(json.loads(self.conn.execute("SELECT snapshot_json FROM tournament_limitless").fetchone()[0]), self.data)
        self.assertFalse(self.call("start_round", expected_round=1)["ok"])
        self.assertFalse(self.call("unlink_limitless")["ok"])
        self.assertFalse(self.call("map_limitless", mapping="alice=bob")["ok"])

    def test_stale_data_absent_next_round_and_future_local_round_are_rejected(self):
        self.roster()
        self.conn.execute("UPDATE tournament_limitless SET synced_at=?", (int(time.time()) - 301,)); self.conn.commit()
        self.assertFalse(self.call("start_round", expected_round=0)["ok"])
        self.bind(); self.call("start_round", expected_round=0)
        for m in self.data["pairings"]: m["result"] = "a"
        self.publish(self.data)
        self.assertIn("尚未公布下一轮", self.call("start_round", expected_round=1)["message"])
        self.assertFalse(self.call("detail", pairing_round=2)["ok"])

    def test_permissions_mapping_uniqueness_and_source_ranks(self):
        for action in ("link_limitless", "sync_limitless", "unlink_limitless", "map_limitless", "complete_limitless"):
            self.assertFalse(self.call(action, user="alice", url=EXTERNAL)["ok"])
        self.assertFalse(self.call("map_limitless", mapping="alice=alice\nbob=alice")["ok"])
        self.assertFalse(self.call("map_limitless", mapping="Alice=alice")["ok"])
        self.roster()
        self.data["standings"][0]["placing"] = 4; self.publish(self.data)
        standing = next(e for e in self.call("detail")["standings"] if e["nickname"] == "ALICE")
        self.assertEqual(standing["rank"], 4)
        self.assertNotIn("mapping", self.call("detail", user="alice")["limitless"])

    def test_completion_requires_all_source_rounds_and_rewards_once(self):
        self.roster(); self.call("start_round", expected_round=0)
        self.next_round(); self.publish(self.data)
        self.assertFalse(self.call("complete_limitless", finished=True)["ok"])
        self.call("start_round", expected_round=1)
        for m in self.data["pairings"]: m["result"] = "a"
        self.publish(self.data)
        self.assertFalse(self.call("complete_limitless")["ok"])
        answer = self.call("complete_limitless", finished=True)
        self.assertTrue(answer["ok"], answer)
        self.assertEqual(answer["tournament"]["phase"], "complete")
        self.assertEqual(self.conn.execute("SELECT SUM(coins) FROM task_rewards WHERE category='tournament'").fetchone()[0], 130)
        self.assertFalse(self.call("complete_limitless", finished=True)["ok"])
        self.assertFalse(self.call("sync_limitless")["ok"])

    def test_network_jobs_are_nonblocking_cached_and_survive_restart(self):
        self.conn.execute("UPDATE tournament_limitless SET synced_at=0,snapshot_json='{}'"); self.conn.commit()
        started, release = threading.Event(), threading.Event()
        def slow(_):
            started.set(); release.wait(3); return self.data
        with patch.object(limitless, "snapshot", side_effect=slow):
            before = time.monotonic()
            self.assertTrue(self.call("sync_limitless")["ok"])
            self.assertLess(time.monotonic() - before, 1)
            self.assertTrue(started.wait(1))
            self.assertTrue(self.call("detail")["limitless"]["syncing"])
            self.call("sync_limitless")
            release.set()
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                with limitless._lock:
                    if all(v is not None for v in limitless._jobs.values()): break
                time.sleep(0.01)
        limitless.tick(self.conn)
        self.assertGreater(self.call("detail")["limitless"]["synced_at"], 0)
        path = self.conn.execute("PRAGMA database_list").fetchone()[2]
        self.conn.close(); self.conn = account_store.database(Path(path))
        self.assertEqual(self.call("detail", external_view="pairings")["limitless"]["entries"][0]["table"], 7)

    def test_api_outcomes_live_single_bracket_and_url_security(self):
        details = {"name": "淘汰签表", "phases": [{"phase": 1, "type": "SINGLE_BRACKET", "mode": "BO3", "rounds": 1}]}
        pairs = [{"phase": 1, "round": 12, "match": label, "player1": a, "player2": b, "winner": winner}
                 for label, a, b, winner in (("T4-1", "alice", "bob", "alice"), ("T4-2", "carol", "dave", "carol"), ("T2-1", "alice", "carol", None))]
        with patch.object(limitless, "_fetch", side_effect=[details, [], pairs]):
            bracket = limitless.snapshot(EXTERNAL)
        self.assertEqual([m["round"] for m in bracket["pairings"]], [1, 1, 2])
        self.data = bracket; self.bind(); self.roster()
        self.assertTrue(self.call("start_round", expected_round=0)["ok"])
        second = self.call("start_round", expected_round=1)
        self.assertTrue(second["ok"], second)
        self.assertEqual(second["pairings"][0]["external_match"], "T2-1")
        self.assertEqual(limitless.tournament_id(f"{limitless.BASE}/tournament/{EXTERNAL}/pairings?round=1"), EXTERNAL)
        for url in ("http://127.0.0.1/", f"https://play.limitlesstcg.com.evil/tournament/{EXTERNAL}", f"https://user@play.limitlesstcg.com/tournament/{EXTERNAL}"):
            with self.assertRaises(ValueError): limitless.tournament_id(url)
        outcomes = [{"phase": 1, "round": 1, "table": i, "player1": "alice", "player2": b, "winner": w}
                    for i, b, w in ((1, "bob", 0), (2, "bob", -1), (3, None, "alice"), (4, None, -1), (5, "bob", None))]
        with patch.object(limitless, "_fetch", side_effect=[{"name": "结果", "phases": []}, [], outcomes]):
            self.assertEqual([m["result"] for m in limitless.snapshot(EXTERNAL)["pairings"]], ["tie", "double_loss", "bye", "auto_loss", "pending"])

    def test_rate_limit_and_bounded_response(self):
        error = HTTPError("https://play.limitlesstcg.com", 429, "rate", {"Retry-After": "600"}, io.BytesIO())
        with patch.object(limitless, "build_opener") as opener:
            opener.return_value.open.side_effect = error
            with self.assertRaises(limitless.SyncError) as caught: limitless._fetch(EXTERNAL, "pairings")
            self.assertEqual(caught.exception.retry_after, 600)
        with patch.object(limitless, "build_opener") as opener:
            opener.return_value.open.return_value.__enter__.return_value.read.return_value = b"x" * (limitless.MAX_BYTES + 1)
            with self.assertRaises(limitless.SyncError): limitless._fetch(EXTERNAL, "pairings")

    def test_seeded_bracket_byes_keep_top_seeds_apart(self):
        self.assertEqual(knockout_pairs(list(range(1, 7))), [(1, None), (4, 5), (2, None), (3, 6)])

    def test_partial_source_round_cannot_be_imported(self):
        self.roster()
        self.data["pairings"].pop(); self.bind()
        answer = self.call("start_round", expected_round=0)
        self.assertFalse(answer["ok"])
        self.assertIn("不完整轮次", answer["message"])
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM tournament_rounds").fetchone()[0], 0)

    def test_scheduled_round_waits_for_source_results_and_next_pairings(self):
        self.roster(); self.call("start_round", expected_round=0)
        now = int(time.time())
        self.assertTrue(self.call("schedule", task="start_round", due_at=now + 2, expected_round=1)["ok"])
        store.tick(self.conn, now + 3)
        status, message = self.conn.execute("SELECT status,message FROM tournament_schedules WHERE tournament_id=?", (self.tid,)).fetchone()
        self.assertEqual(status, "waiting"); self.assertIn("Limitless", message)
        for m in self.data["pairings"]: m["result"] = "a"
        self.publish(self.data); store.tick(self.conn, now + 4)
        self.assertEqual(self.conn.execute("SELECT status FROM tournament_schedules WHERE tournament_id=?", (self.tid,)).fetchone()[0], "waiting")
        self.next_round(); self.publish(self.data); store.tick(self.conn, now + 5)
        self.assertEqual(self.conn.execute("SELECT status FROM tournament_schedules WHERE tournament_id=?", (self.tid,)).fetchone()[0], "done")
        self.assertEqual(store.config(self.conn, self.tid)["round_number"], 2)

    def test_bye_does_not_renumber_other_source_tables(self):
        self.roster(); self.call("start_round", expected_round=0)
        for m in self.data["pairings"]: m["result"] = "a"
        self.data["standings"][-1].update(drop=True, drop_round=1)
        self.data["pairings"].extend([
            {"phase": 1, "round": 2, "table": 0, "match": "", "players": ["alice", ""], "names": ["alice", ""], "result": "bye"},
            {"phase": 1, "round": 2, "table": 9, "match": "", "players": ["bob", "carol"], "names": ["bob", "carol"], "result": "pending"}])
        self.publish(self.data)
        answer = self.call("start_round", expected_round=1)
        self.assertTrue(answer["ok"], answer)
        self.assertEqual([p["table"] for p in answer["pairings"]], [0, 9])
        self.assertTrue(answer["pairings"][0]["bye"])

    def test_multiple_unassigned_auto_losses_are_distinct_and_stable(self):
        raw = [{"phase": 1, "round": 1, "table": None, "player1": p, "winner": -1} for p in ("bob", "alice")]
        raw.append({"phase": 1, "round": 1, "table": 9, "player1": "carol", "player2": "dave", "winner": None})
        details = {"name": "无桌号条目", "phases": self.data["phases"]}
        standings = [{"player": p["player"], "name": p["name"], "record": {}, "placing": p["placing"]} for p in self.data["standings"]]
        with patch.object(limitless, "_fetch", side_effect=[details, standings, raw]):
            self.data = limitless.snapshot(EXTERNAL)
        self.assertEqual([m["players"][0] for m in self.data["pairings"]], ["alice", "bob", "carol"])
        self.bind(); self.roster()
        answer = self.call("start_round", expected_round=0)
        self.assertTrue(answer["ok"], answer)
        self.assertEqual([p["table"] for p in answer["pairings"]], [-1, 0, 9])
        self.assertEqual([p["result"] for p in answer["pairings"]], [-2, -2, None])
        self.publish(self.data)
        self.assertFalse(self.call("detail")["limitless"]["error"])

    def test_unpublished_future_phase_and_live_double_bracket_cannot_be_bypassed(self):
        self.roster(); self.call("start_round", expected_round=0)
        self.next_round(); self.publish(self.data); self.call("start_round", expected_round=1)
        for m in self.data["pairings"]: m["result"] = "a"
        self.data["phases"].append({"phase": 2, "type": "SINGLE_BRACKET", "mode": "BO5", "rounds": 1})
        self.publish(self.data)
        self.assertIn("未公布签表的阶段", self.call("complete_limitless", finished=True)["message"])
        self.data["phases"][-1]["type"] = "DOUBLE_BRACKET"
        self.data["pairings"].append({"phase": 2, "round": 3, "table": 1, "match": "W1-1", "players": ["alice", "bob"], "names": ["alice", "bob"], "result": "pending"})
        self.publish(self.data)
        self.assertIn("实时双败树", self.call("start_round", expected_round=2)["message"])

    def test_corrected_source_table_blocks_replacement_and_generation_prevents_late_jobs(self):
        self.roster(); self.call("start_round", expected_round=0)
        changed = copy.deepcopy(self.data); changed["pairings"][0]["table"] = 8
        self.publish(changed)
        self.assertIn("签表已更改", self.call("detail")["limitless"]["error"])
        self.conn.execute("UPDATE tournament_limitless SET generation='new'"); self.conn.commit()
        self.data["title"] = "stale worker"
        self.publish(self.data)
        self.assertNotEqual(self.call("detail")["limitless"]["title"], "stale worker")


if __name__ == "__main__":
    unittest.main()
