"""Multi-stage score consent, double elimination, threshold exits and wallet grants."""
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store
import community_store
import tournament_store as store
import tournament_rules as rules


class StageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.conn = account_store.database(Path(self.temp.name) / "players.db")
        self.people = []
        for name in ["bigcake", "organizer", *[f"player{i}" for i in range(16)]]:
            id = self.conn.execute("INSERT INTO players(username,nickname,password_salt,password_hash,created_at) VALUES(?,?,X'',X'',0)", (name, name)).lastrowid
            self.people.append({"ok": True, "username": name, "player_id": id})
        self.conn.commit()
        self.admin = self.people[0]

    def tearDown(self):
        self.conn.close()
        self.temp.cleanup()

    def create(self, stages, count=4, owner=None):
        answer = store.handle(self.conn, {"action": "create", "title": "测试", "start_at": int(time.time())+3600, "stages": stages}, owner or self.admin)
        self.assertTrue(answer["ok"], answer)
        self.tid = answer["tournament"]["id"]
        self.conn.execute("UPDATE tournaments SET phase='locked' WHERE id=?", (self.tid,))
        self.conn.executemany("INSERT INTO tournament_members(tournament_id,player_id,joined_at,in_roster,seed) VALUES(?,?,0,1,?)", ((self.tid, e["player_id"], i) for i, e in enumerate(self.people[2:count+2], 1)))
        self.conn.commit()

    def call(self, action, account=None, **data):
        return store.handle(self.conn, {"action": action, "id": self.tid, **data}, account or self.admin)

    def advance(self):
        number = store.config(self.conn, self.tid)["round_number"]
        answer = self.call("start_round", expected_round=number)
        self.assertTrue(answer["ok"], answer)
        return answer

    def finish_pairs(self, winner=0):
        current = self.call("detail")
        target = {3:2, 6:3, 7:2}.get(current["tournament"]["game_format"],1)
        for pair in current["pairings"]:
            if pair["bye"]:
                continue
            scores = [target,0] if winner == 0 else [0,target]
            answer = self.call("judge_result", pairing_id=pair["id"], revision=pair["revision"], result=winner, scores=scores)
            self.assertTrue(answer["ok"], answer)

    def test_single_semis_bo3_to_bo5_final_and_exact_rewards(self):
        self.create([{"kind":"single_elimination", "game_format":3, "advance":{"mode":"rank", "count":2}}, {"kind":"single_elimination", "game_format":6}])
        self.advance(); self.finish_pairs()
        answer = self.advance()
        self.assertEqual(answer["tournament"]["stage_index"], 1)
        self.assertEqual(answer["tournament"]["game_format"], 6)
        self.finish_pairs(); self.advance()
        amounts = sorted(row[0] for row in self.conn.execute("SELECT coins FROM task_rewards WHERE category='tournament'"))
        self.assertEqual(amounts, [20,20,40,50])
        self.assertFalse(self.call("start_round", expected_round=2)["ok"])
        self.assertEqual(sum(amounts), self.conn.execute("SELECT SUM(coins) FROM task_wallets").fetchone()[0])

    def test_single_bracket_keeps_winners_in_fixed_slots_with_seeded_byes(self):
        self.create([{"kind": "single_elimination", "game_format": 1}], 6)
        first = self.advance()
        ids = [e["player_id"] for e in self.people[2:8]]
        actual = self.conn.execute("SELECT player_a,player_b FROM tournament_pairings WHERE tournament_id=? ORDER BY table_number", (self.tid,)).fetchall()
        self.assertEqual(actual, [(ids[0], None), (ids[3], ids[4]), (ids[1], None), (ids[2], ids[5])])
        self.finish_pairs(winner=1)
        second = self.advance()
        self.assertEqual([p["names"] for p in second["pairings"]], [[self.people[2]["username"], self.people[6]["username"]], [self.people[3]["username"], self.people[7]["username"]]])
        self.finish_pairs(); final = self.advance()
        self.assertEqual(final["pairings"][0]["names"], [self.people[2]["username"], self.people[3]["username"]])

    def test_double_elimination_final_reset_and_no_early_elimination(self):
        for count in (2,3,5,8):
            self.create([{"kind":"double_elimination", "game_format":1}], count)
            final_reset = False
            for _ in range(35):
                answer = self.advance()
                if answer["tournament"]["phase"] == "complete":
                    break
                entries = rules.standings(self.conn, self.tid)
                alive = [e for e in entries if e["state"] == "active"]
                if len(alive) == 2 and not final_reset:
                    pair = answer["pairings"][0]
                    row = self.conn.execute("SELECT player_a,player_b FROM tournament_pairings WHERE id=?", (pair["id"],)).fetchone()
                    loser = next(e for e in alive if e["losses"] == 0)["player_id"]
                    self.finish_pairs(winner=1 if row[0] == loser else 0)
                    self.assertEqual(len([e for e in rules.standings(self.conn,self.tid) if e["state"] == "active"]), 2)
                    final_reset = True
                else:
                    self.finish_pairs()
            else:
                self.fail("double elimination failed to terminate")
            self.assertTrue(final_reset)
            entries = rules.standings(self.conn, self.tid)
            self.assertEqual(sum(e["losses"] == 2 for e in entries), count-1)
            self.assertEqual(sorted(e["placement"] for e in entries)[:2], [1,2])

    def test_round_robin_each_pair_once_with_byes(self):
        for count in (4,5):
            self.create([{"kind":"round_robin", "game_format":7}], count)
            seen = set()
            for _ in range(count + 1):
                answer = self.advance()
                if answer["tournament"]["phase"] == "complete":break
                for a,b in self.conn.execute("SELECT player_a,player_b FROM tournament_pairings WHERE tournament_id=? AND round_number=?", (self.tid,answer["tournament"]["round_number"])):
                    if b is None:continue
                    pair=tuple(sorted((a,b)));self.assertNotIn(pair,seen);seen.add(pair)
                self.finish_pairs()
            self.assertEqual(len(seen), count*(count-1)//2)

    def test_score_agreement_requires_same_score_and_points_use_orientation(self):
        self.create([{"kind":"swiss", "game_format":3, "rounds":1, "points":{"win":5,"draw":2,"loss":0,"bye":5,"scores":{"2:0":5,"2:1":3,"1:2":1,"0:2":0}}}],2)
        answer=self.advance();pair=answer["pairings"][0]
        a,b=self.conn.execute("SELECT player_a,player_b FROM tournament_pairings WHERE id=?",(pair["id"],)).fetchone()
        people={e["player_id"]:e for e in self.people}
        self.assertTrue(self.call("report_result",people[a],pairing_id=pair["id"],revision=0,result=0,scores=[2,1])["ok"])
        self.assertFalse(self.call("confirm_result",people[b],pairing_id=pair["id"],revision=1,result=0,scores=[2,0])["ok"])
        self.assertTrue(self.call("confirm_result",people[b],pairing_id=pair["id"],revision=1,result=0,scores=[2,1])["ok"])
        entries=rules.standings(self.conn,self.tid)
        self.assertEqual([e["points"] for e in entries],[3,1])

    def test_score_thresholds_stop_qualifiers_and_eliminate_losses(self):
        self.create([{"kind":"swiss","game_format":1,"rounds":3,"advance":{"mode":"points","points":3,"early":True,"eliminate_losses":1}}, {"kind":"single_elimination","game_format":6}], 8)
        self.advance();self.finish_pairs()
        entries=rules.standings(self.conn,self.tid)
        self.assertEqual(sum(e["state"]=="advanced" for e in entries),4)
        self.assertEqual(sum(e["state"]=="eliminated" for e in entries),4)
        answer=self.advance()
        self.assertEqual(answer["tournament"]["stage_index"],1)
        self.assertEqual(len(answer["pairings"]),2)

    def test_points_cut_is_independent_of_early_exits(self):
        for early in (False, True):
            with self.subTest(early=early):
                self.create([{"kind": "swiss", "game_format": 1, "rounds": 1,
                              "advance": {"mode": "points", "points": 3, "early": early,
                                          "eliminate_losses": 2}},
                             {"kind": "single_elimination", "game_format": 1}], 8)
                self.advance(); self.finish_pairs()
                entries = rules.standings(self.conn, self.tid)
                qualified = {e["player_id"] for e in entries if e["points"] >= 3}
                self.advance()
                promoted = {e["player_id"] for e in rules.standings(self.conn, self.tid)}
                self.assertEqual(promoted, qualified)
                self.assertEqual(len(promoted), 4)

    def test_points_cut_does_not_fill_empty_slots_with_survivors(self):
        self.create([{"kind": "swiss", "game_format": 1, "rounds": 1,
                      "advance": {"mode": "points", "points": 6, "early": False,
                                  "eliminate_losses": 2}},
                     {"kind": "single_elimination", "game_format": 1}], 4)
        self.advance(); self.finish_pairs()
        self.assertTrue(all(e["state"] == "active" for e in rules.standings(self.conn, self.tid)))
        answer = self.call("start_round", expected_round=1)
        self.assertFalse(answer["ok"])
        self.assertEqual(rules.config(self.conn, self.tid)["stage_index"], 0)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM tournament_stage_members WHERE tournament_id=? AND stage_index=1", (self.tid,)).fetchone()[0], 0)

    def test_rank_ties_advance_together_before_knockout(self):
        for mode, expected_count in (("rank", 2), ("rank_tie", 4)):
            with self.subTest(mode=mode):
                self.create([{"kind": "swiss", "game_format": 1, "rounds": 1,
                              "advance": {"mode": mode, "count": 2}},
                             {"kind": "single_elimination", "game_format": 1}], 8)
                self.advance(); self.finish_pairs()
                entries = rules.standings(self.conn, self.tid)
                expected = {e["player_id"] for e in entries[:expected_count]}
                answer = self.advance()
                self.assertEqual({e["player_id"] for e in rules.standings(self.conn, self.tid)}, expected)
                self.assertEqual(len(answer["pairings"]), expected_count // 2)

    def test_rank_ties_do_not_revive_knockout_losers(self):
        self.create([{"kind": "single_elimination", "game_format": 1,
                      "points": {"win": 0, "loss": 0},
                      "advance": {"mode": "rank_tie", "count": 2}},
                     {"kind": "single_elimination", "game_format": 6}], 4)
        self.advance(); self.finish_pairs()
        winners = {e["player_id"] for e in rules.standings(self.conn, self.tid) if e["wins"] == 1}
        self.advance()
        self.assertEqual({e["player_id"] for e in rules.standings(self.conn, self.tid)}, winners)

    def test_rank_tie_cut_uses_boundary_points_and_respects_elimination(self):
        for early in (False, True):
            with self.subTest(early=early):
                self.create([{"kind": "swiss", "game_format": 3, "rounds": 1,
                              "points": {"scores": {"2:0": 5, "0:2": 3, "2:1": 3, "1:2": 0}},
                              "advance": {"mode": "rank_tie", "count": 3, "early": early,
                                          "eliminate_losses": 1}},
                             {"kind": "single_elimination", "game_format": 1}], 8)
                first = self.advance()
                for i, pair in enumerate(first["pairings"]):
                    self.assertTrue(self.call("judge_result", pairing_id=pair["id"], revision=pair["revision"],
                                              result=0, scores=[2, 0] if i < 2 else [2, 1])["ok"])
                entries = rules.standings(self.conn, self.tid)
                expected = {e["player_id"] for e in entries if e["points"] >= 3 and e["state"] != "eliminated"}
                self.assertEqual(len(expected), 4 if early else 6)
                self.advance()
                self.assertEqual({e["player_id"] for e in rules.standings(self.conn, self.tid)}, expected)

    def test_early_states_survive_a_partially_settled_next_round(self):
        self.create([{"kind": "swiss", "game_format": 1, "rounds": 3,
                      "advance": {"mode": "points", "points": 3, "early": True,
                                  "eliminate_losses": 1}},
                     {"kind": "single_elimination", "game_format": 1}], 8)
        first = self.advance()
        for i, pair in enumerate(first["pairings"]):
            self.assertTrue(self.call("judge_result", pairing_id=pair["id"], revision=pair["revision"],
                                      result=0 if i == 0 else -1, scores=[1, 0] if i == 0 else [0, 0])["ok"])
        previous = {e["player_id"]: e["state"] for e in rules.standings(self.conn, self.tid)}
        self.assertEqual(list(previous.values()).count("advanced"), 1)
        self.assertEqual(list(previous.values()).count("eliminated"), 1)
        second = self.advance()
        self.assertEqual({e["player_id"]: e["state"] for e in rules.standings(self.conn, self.tid)}, previous)
        pair = second["pairings"][0]
        self.assertTrue(self.call("judge_result", pairing_id=pair["id"], revision=pair["revision"], result=0, scores=[1, 0])["ok"])
        self.assertEqual({e["player_id"]: e["state"] for e in rules.standings(self.conn, self.tid)}, previous)
        self.finish_pairs()
        entries = rules.standings(self.conn, self.tid)
        self.assertEqual(sum(e["state"] == "advanced" for e in entries), 4)
        self.assertEqual(sum(e["state"] == "eliminated" for e in entries), 4)

    def test_rank_cut_excludes_early_eliminations(self):
        self.create([{"kind": "swiss", "game_format": 1, "rounds": 1,
                      "points": {"win": 1, "loss": 5},
                      "advance": {"mode": "rank", "count": 2, "early": True,
                                  "eliminate_losses": 1}},
                     {"kind": "single_elimination", "game_format": 1}], 4)
        self.advance(); self.finish_pairs()
        survivors = {e["player_id"] for e in rules.standings(self.conn, self.tid) if e["losses"] == 0}
        self.advance()
        self.assertEqual({e["player_id"] for e in rules.standings(self.conn, self.tid)}, survivors)

    def test_roles_revocation_super_management_and_rewards_permissions(self):
        organizer=self.people[1]
        granted=community_store.handle(self.conn,{"action":"set_role","username":"organizer","role":"tournament_admin","enabled":True},self.admin)
        self.assertTrue(granted["ok"])
        self.create([{"kind":"single_elimination"}],owner=organizer)
        self.assertTrue(self.call("update_description",description="super edit")["ok"])
        self.assertFalse(self.call("update_rewards",organizer,rewards={"champion":100,"runner_up":20,"semifinalist":0})["ok"])
        self.assertTrue(self.call("update_rewards",rewards={"champion":100,"runner_up":20,"semifinalist":0})["ok"])
        community_store.handle(self.conn,{"action":"set_role","username":"organizer","role":"tournament_admin","enabled":False},self.admin)
        self.assertFalse(self.call("delete",organizer)["ok"])
        self.assertTrue(self.call("delete")["ok"])

    def test_invalid_stage_config_never_creates_tournament(self):
        for stages in ([], [{"kind":"single_elimination","game_format":7}], [{"kind":"swiss","points":{"scores":{"9:0":4}}}], [{"kind":"swiss","advance":{"mode":"points","points":-1}}]):
            before=self.conn.execute("SELECT COUNT(*) FROM tournaments").fetchone()[0]
            answer=store.handle(self.conn,{"action":"create","title":"invalid","start_at":int(time.time())+100,"stages":stages},self.admin)
            self.assertFalse(answer["ok"])
            self.assertEqual(before,self.conn.execute("SELECT COUNT(*) FROM tournaments").fetchone()[0])


if __name__ == "__main__":
    unittest.main()
