"""Swiss matching, cuts, mutual result consent, adjudication and server timers."""
import random
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store as accounts
import tournament_store as competitions
from tournament_pairing import perfect_matching
from support.tournament_decks import admit, deck


class CompetitionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = Path(self.directory.name) / "players.sqlite3"
        self.conn = accounts.database(self.path)
        self.players = {}
        for name in ("bigcake", *[f"player_{i}" for i in range(18)]):
            player_id = self.conn.execute("""INSERT INTO players(username,nickname,password_salt,password_hash,created_at)
                VALUES(?,?,?,?,?)""", (name, name, b"", b"", 0)).lastrowid
            self.players[name] = {"ok": True, "username": name, "player_id": player_id}
        self.conn.commit()
        self.start_at = int(time.time()) + 3600
        self.competition_id = self.call("create", title="瑞士轮测试", start_at=self.start_at)["tournament"]["id"]

    def tearDown(self):
        self.conn.close()
        self.directory.cleanup()

    def call(self, action, user="bigcake", **data):
        return competitions.handle(self.conn, {"action": action, "id": getattr(self, "competition_id", 0), **data}, self.players[user])

    def roster(self, count=6, format_name="swiss", rounds=0, interval=0):
        self.assertTrue(self.call("configure", format=format_name, swiss_rounds=rounds, round_interval=interval)["ok"])
        for index in range(count):
            self.call("join", f"player_{index}")
        self.conn.execute("UPDATE tournaments SET start_at=? WHERE id=?", (int(time.time()), self.competition_id))
        competitions.tick(self.conn)
        for index in range(count):
            self.call("checkin", f"player_{index}")
        self.call("close_checkin")

    def pairs(self):
        return self.conn.execute("""SELECT id,player_a,player_b,result,revision FROM tournament_pairings
            WHERE tournament_id=? AND round_number=(SELECT round_number FROM tournaments WHERE id=?) ORDER BY table_number""",
            (self.competition_id, self.competition_id)).fetchall()

    def player_name(self, player_id):
        return next(name for name, account in self.players.items() if account["player_id"] == player_id)

    def agree(self, pairing, result=0):
        pairing_id, a, b, _, revision = pairing
        self.assertTrue(self.call("report_result", self.player_name(a), pairing_id=pairing_id, result=result, revision=revision)["ok"])
        answer = self.call("confirm_result", self.player_name(b), pairing_id=pairing_id, result=result, revision=revision + 1)
        self.assertTrue(answer["ok"])

    def test_swiss_rounds_scores_no_rematches_and_completion(self):
        self.roster()
        seen = set()
        for number in range(3):
            answer = self.call("start_round", expected_round=number)
            self.assertTrue(answer["ok"])
            self.assertEqual(answer["tournament"]["total_swiss_rounds"], 3)
            self.assertFalse(self.call("start_round", expected_round=number)["ok"])
            participants = []
            for pair in self.pairs():
                key = frozenset(pair[1:3])
                self.assertNotIn(key, seen)
                seen.add(key)
                participants.extend(pair[1:3])
                self.agree(pair, -1 if number == 0 and pair[0] == self.pairs()[0][0] else 0)
            self.assertEqual(len(set(participants)), 6)
        final = self.call("start_round", expected_round=3)
        self.assertEqual(final["tournament"]["phase"], "complete")
        self.assertEqual(len(final["standings"]), 6)
        self.assertEqual(sum(entry["points"] for entry in final["standings"]), 26)

    def test_odd_roster_allocates_distinct_byes(self):
        self.roster(count=5, rounds=3)
        byes = set()
        for number in range(3):
            self.assertTrue(self.call("start_round", expected_round=number)["ok"])
            for pairing in self.pairs():
                if pairing[2] is None:
                    self.assertNotIn(pairing[1], byes)
                    byes.add(pairing[1])
                    self.assertEqual(pairing[3], 0)
                else:
                    self.agree(pairing)
        self.assertEqual(len(byes), 3)

    def test_top_four_seeded_semifinals_and_final(self):
        self.roster(count=6, format_name="swiss_top4", rounds=2)
        for number in range(2):
            self.call("start_round", expected_round=number)
            for pairing in self.pairs():
                self.agree(pairing)
        seeds = [entry["player_id"] for entry in competitions.standings_for(self.conn, self.competition_id)[:4]]
        answer = self.call("start_round", expected_round=2)
        self.assertEqual(answer["tournament"]["round_stage"], "semifinal")
        self.assertEqual([tuple(pair[1:3]) for pair in self.pairs()], [(seeds[0], seeds[3]), (seeds[1], seeds[2])])
        winners = []
        for pairing in self.pairs():
            self.assertFalse(self.call("judge_result", pairing_id=pairing[0], result=-1, revision=pairing[4])["ok"])
            winners.append(pairing[1])
            self.agree(pairing)
        answer = self.call("start_round", expected_round=3)
        self.assertEqual(answer["tournament"]["round_stage"], "final")
        self.assertEqual(tuple(self.pairs()[0][1:3]), tuple(winners))
        self.agree(self.pairs()[0], 1)
        final = self.call("start_round", expected_round=4)
        self.assertEqual(final["tournament"]["phase"], "complete")
        self.assertEqual(sorted(entry["placement"] for entry in final["standings"] if "placement" in entry), [1, 2, 3, 3])

    def test_all_knockout_sizes_seed_advance_and_record_placements(self):
        brackets = {
            2: [(1, 2)],
            4: [(1, 4), (2, 3)],
            8: [(1, 8), (4, 5), (2, 7), (3, 6)],
            16: [(1, 16), (8, 9), (4, 13), (5, 12), (2, 15), (7, 10), (3, 14), (6, 11)],
        }
        stages = {16: "round_of_16", 8: "quarterfinal", 4: "semifinal", 2: "final"}
        for cut, bracket in brackets.items():
            with self.subTest(cut=cut):
                format_name = f"swiss_top{cut}"
                created = self.call("create", title=f"前{cut}名淘汰赛", format=format_name, swiss_rounds=1, start_at=self.start_at)
                self.assertTrue(created["ok"])
                self.competition_id = created["tournament"]["id"]
                self.roster(count=cut + 2, format_name=format_name, rounds=1)
                self.assertTrue(self.call("start_round", expected_round=0)["ok"])
                for pairing in self.pairs():
                    self.agree(pairing)
                swiss = competitions.standings_for(self.conn, self.competition_id)
                seeds = [entry["player_id"] for entry in swiss[:cut]]
                expected_pairs = [(seeds[a - 1], seeds[b - 1]) for a, b in bracket]
                expected_placements = {}
                self.conn.close()
                self.conn = accounts.database(self.path)
                self.assertEqual(self.call("detail")["tournament"]["format"], format_name)
                self.assertFalse(self.call("configure", format="swiss", swiss_rounds=1)["ok"])
                number, remaining = 1, cut
                while remaining >= 2:
                    answer = self.call("start_round", expected_round=number)
                    self.assertTrue(answer["ok"], answer.get("message"))
                    self.assertEqual(answer["tournament"]["round_stage"], stages[remaining])
                    pairs = self.pairs()
                    self.assertEqual([pair[1:3] for pair in pairs], expected_pairs)
                    self.assertEqual(len(pairs), remaining // 2)
                    self.assertFalse(self.call("start_round", expected_round=number + 1)["ok"])
                    winners = []
                    for index, pairing in enumerate(pairs):
                        self.assertFalse(self.call("report_result", self.player_name(pairing[1]),
                                                  pairing_id=pairing[0], result=-1, revision=pairing[4])["ok"])
                        self.assertFalse(self.call("judge_result", pairing_id=pairing[0], result=-1, revision=pairing[4])["ok"])
                        result = (number + index) % 2
                        winners.append(pairing[1 + result])
                        expected_placements[pairing[2 - result]] = remaining // 2 + 1
                        self.agree(pairing, result)
                    if remaining == 2:
                        expected_placements[winners[0]] = 1
                    standings = competitions.standings_for(self.conn, self.competition_id)
                    self.assertEqual([{k: v for k, v in entry.items() if k != "placement"} for entry in standings], swiss)
                    self.assertEqual({entry["player_id"]: entry["placement"] for entry in standings if "placement" in entry},
                                     expected_placements)
                    expected_pairs = list(zip(winners[::2], winners[1::2]))
                    remaining //= 2
                    number += 1
                answer = self.call("start_round", expected_round=number)
                self.assertTrue(answer["ok"])
                self.assertEqual(answer["tournament"]["phase"], "complete")
                self.assertEqual(len(expected_placements), cut)
                self.assertFalse(self.call("start_round", expected_round=number)["ok"])

    def test_each_knockout_size_requires_enough_checked_in_players(self):
        for cut in (2, 4, 8, 16):
            with self.subTest(cut=cut):
                created = self.call("create", title="淘汰赛人数校验", start_at=self.start_at)
                self.competition_id = created["tournament"]["id"]
                self.roster(count=cut - 1, format_name=f"swiss_top{cut}", rounds=1)
                answer = self.call("start_round", expected_round=0)
                self.assertFalse(answer["ok"])
                self.assertIn(str(cut), answer["message"])
                self.assertEqual(self.call("detail")["tournament"]["round_number"], 0)
                self.assertEqual(self.pairs(), [])
        for invalid in ("swiss_top0", "swiss_top3", "swiss_top32"):
            self.assertFalse(self.call("configure", format=invalid)["ok"])

    def test_timer_advances_sixteen_player_knockout_until_complete(self):
        self.roster(count=16, format_name="swiss_top16", rounds=1, interval=60)
        self.assertTrue(self.call("start_round", expected_round=0)["ok"])
        for number, stage in enumerate(("swiss", "round_of_16", "quarterfinal", "semifinal", "final"), 1):
            current = self.call("detail")["tournament"]
            self.assertEqual((current["round_number"], current["round_stage"]), (number, stage))
            due = current["round_started_at"] + 60
            competitions.tick(self.conn, due)
            self.assertEqual(self.call("detail")["tournament"]["round_number"], number)
            for pairing in self.pairs():
                self.agree(pairing, 1)
            competitions.tick(self.conn, due + 1)
        self.assertEqual(self.call("detail")["tournament"]["phase"], "complete")
        competitions.tick(self.conn, due + 120)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM tournament_rounds WHERE tournament_id=?",
                                           (self.competition_id,)).fetchone()[0], 5)

    def test_disputed_results_need_consent_or_owner_judgment(self):
        self.roster(count=4, rounds=1)
        self.call("start_round", expected_round=0)
        pair = self.pairs()[0]
        first, second = self.player_name(pair[1]), self.player_name(pair[2])
        self.assertFalse(self.call("report_result", "bigcake", pairing_id=pair[0], result=0, revision=0)["ok"])
        self.assertTrue(self.call("report_result", first, pairing_id=pair[0], result=0, revision=0)["ok"])
        self.assertFalse(self.call("confirm_result", second, pairing_id=pair[0], result=0, revision=0)["ok"])
        self.assertTrue(self.call("report_result", second, pairing_id=pair[0], result=1, revision=1)["ok"])
        self.assertIsNone(self.pairs()[0][3])
        self.assertFalse(self.call("start_round", expected_round=1)["ok"])
        self.assertFalse(self.call("judge_result", first, pairing_id=pair[0], result=0, revision=2)["ok"])
        self.assertTrue(self.call("judge_result", pairing_id=pair[0], result=0, revision=2)["ok"])
        self.assertEqual(self.pairs()[0][3], 0)
        self.assertFalse(self.call("confirm_result", second, pairing_id=pair[0], result=0, revision=3)["ok"])

    def test_timed_checkin_restart_and_wait_for_adjudication(self):
        now = int(time.time())
        self.call("join", "player_0")
        self.call("join", "player_1")
        self.call("configure", start_at=now + 5)
        self.assertTrue(self.call("schedule", task="open_checkin", due_at=now + 5, expected_round=0)["ok"])
        self.assertTrue(self.call("schedule", task="close_checkin", due_at=now + 10, expected_round=0)["ok"])
        self.assertTrue(self.call("schedule", task="start_round", due_at=now + 15, expected_round=0)["ok"])
        self.conn.close()
        self.conn = accounts.database(self.path)
        with patch("tournament_store.time.time", return_value=now + 5):
            competitions.tick(self.conn, now + 5)
        self.call("checkin", "player_0")
        self.call("checkin", "player_1")
        competitions.tick(self.conn, now + 10)
        self.assertEqual(self.call("detail")["tournament"]["phase"], "locked")
        competitions.tick(self.conn, now + 15)
        self.assertEqual(self.call("detail")["tournament"]["round_number"], 1)
        self.call("schedule", task="start_round", due_at=now + 20, expected_round=1)
        competitions.tick(self.conn, now + 20)
        self.assertEqual(self.call("detail")["schedules"][0]["status"], "waiting")
        pair = self.pairs()[0]
        self.call("judge_result", pairing_id=pair[0], result=1, revision=pair[4])
        competitions.tick(self.conn, now + 21)
        self.assertEqual(self.call("detail")["tournament"]["phase"], "complete")
        competitions.tick(self.conn, now + 30)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM tournament_rounds").fetchone()[0], 1)

    def test_automatic_interval_requires_all_results_and_cannot_change_format(self):
        self.roster(count=4, rounds=2, interval=60)
        self.call("start_round", expected_round=0)
        start = self.call("detail")["tournament"]["round_started_at"]
        competitions.tick(self.conn, start + 60)
        self.assertEqual(self.call("detail")["tournament"]["round_number"], 1)
        self.assertTrue(self.call("detail")["tournament"]["timer_notice"])
        self.assertFalse(self.call("configure", format="swiss_top4", swiss_rounds=2, round_interval=60)["ok"])
        for pairing in self.pairs():
            self.agree(pairing)
        competitions.tick(self.conn, start + 61)
        self.assertEqual(self.call("detail")["tournament"]["round_number"], 2)

    def test_game_settlement_and_expired_game_ticket_do_not_touch_rank(self):
        self.roster(count=4, rounds=1)
        self.call("start_round", expected_round=0)
        pairing = self.pairs()[0]
        ticket = self.conn.execute("SELECT match_id FROM tournament_pairings WHERE id=?", (pairing[0],)).fetchone()[0]
        self.assertFalse(competitions.handle_game(self.conn, {"action": "lookup", "match_id": ticket, "player_id": self.players["bigcake"]["player_id"]})["ok"])
        before = self.conn.execute("SELECT id,elo,rank_step,rank_stars,rank_streak FROM players").fetchall()
        self.assertTrue(accounts.handle_match(self.conn, {"action": "create", "match_id": ticket, "mode": "casual", "players": list(pairing[1:3]), "deck_signatures": admit(self.conn, self.competition_id, pairing[1:3])})["ok"])
        self.assertFalse(self.call("report_result", self.player_name(pairing[1]), pairing_id=pairing[0], result=0, revision=1)["ok"])
        self.assertTrue(accounts.handle_match(self.conn, {"action": "start", "match_id": ticket})["ok"])
        self.assertTrue(accounts.handle_match(self.conn, {"action": "settle", "match_id": ticket, "winner": 1})["ok"])
        self.assertEqual(self.pairs()[0][3], 1)
        self.assertEqual(self.call("detail")["pairings"][0]["source"], "game")
        self.assertEqual(self.conn.execute("SELECT id,elo,rank_step,rank_stars,rank_streak FROM players").fetchall(), before)
        second = self.pairs()[1]
        ticket = self.conn.execute("SELECT match_id FROM tournament_pairings WHERE id=?", (second[0],)).fetchone()[0]
        accounts.handle_match(self.conn, {"action": "create", "match_id": ticket, "mode": "casual", "players": list(second[1:3]), "deck_signatures": admit(self.conn, self.competition_id, second[1:3])})
        competitions.tick(self.conn, int(time.time()) + 91)
        new_ticket = self.conn.execute("SELECT match_id FROM tournament_pairings WHERE id=?", (second[0],)).fetchone()[0]
        self.assertNotEqual(ticket, new_ticket)
        self.assertIsNone(self.pairs()[1][3])
        self.assertFalse(competitions.handle_game(self.conn, {"action": "lookup", "match_id": ticket, "player_id": second[1]})["ok"])

    def test_owner_permissions_schedule_cancellation_and_roster_minimum(self):
        for action in ("configure", "schedule", "cancel_schedule", "start_round"):
            self.assertFalse(self.call(action, "player_0", expected_round=0)["ok"])
        for settings in ({"format": "invalid"}, {"swiss_rounds": -1}, {"swiss_rounds": True}, {"round_interval": -1}):
            self.assertFalse(self.call("configure", **settings)["ok"])
        future = int(time.time()) + 100
        self.call("schedule", task="open_checkin", due_at=future, expected_round=0)
        task_id = self.call("detail")["schedules"][0]["id"]
        self.assertTrue(self.call("cancel_schedule", schedule_id=task_id)["ok"])
        competitions.tick(self.conn, future)
        self.assertEqual(self.call("detail")["tournament"]["phase"], "registration")
        self.roster(count=3, format_name="swiss_top4")
        self.assertFalse(self.call("start_round", expected_round=0)["ok"])

    def test_all_game_formats_persist_reach_relay_and_settle_without_rank_changes(self):
        for game_format in competitions.GAME_FORMATS:
            with self.subTest(game_format=game_format):
                created = self.call("create", title="指定赛制", game_format=game_format, start_at=self.start_at)
                self.competition_id = created["tournament"]["id"]
                self.roster(count=2, rounds=1)
                self.conn.close()
                self.conn = accounts.database(self.path)
                self.assertEqual(self.call("detail")["tournament"]["game_format"], game_format)
                self.call("start_round", expected_round=0)
                self.assertFalse(self.call("configure", game_format=1 if game_format != 1 else 3, swiss_rounds=1)["ok"])
                pair = self.pairs()[0]
                ticket = self.conn.execute("SELECT match_id FROM tournament_pairings WHERE id=?", (pair[0],)).fetchone()[0]
                signatures = admit(self.conn, self.competition_id, pair[1:3])
                lookup = competitions.handle_game(self.conn, {"action": "lookup", "match_id": ticket, "player_id": pair[1], "deck": deck(game_format)})
                self.assertEqual(lookup["game_format"], game_format)
                expected_mode = competitions.game_mode(game_format)
                self.assertEqual(lookup["mode"], expected_mode)
                for bad_mode in ("ranked", "casual" if game_format in (4, 5) else "exploration"):
                    self.assertFalse(accounts.handle_match(self.conn, {"action": "create", "match_id": ticket, "players": list(pair[1:3]), "mode": bad_mode})["ok"])
                before = self.conn.execute("SELECT id,elo,rank_step,rank_stars FROM players").fetchall()
                self.assertTrue(accounts.handle_match(self.conn, {"action": "create", "match_id": ticket, "players": list(pair[1:3]), "mode": expected_mode, "deck_signatures": signatures})["ok"])
                accounts.handle_match(self.conn, {"action": "start", "match_id": ticket})
                self.assertTrue(accounts.handle_match(self.conn, {"action": "settle", "match_id": ticket, "winner": 1})["ok"])
                self.assertEqual(self.pairs()[0][3], 1)
                self.assertEqual(self.conn.execute("SELECT id,elo,rank_step,rank_stars FROM players").fetchall(), before)

    def test_delete_running_competition_cancels_games_tasks_and_stale_tickets(self):
        self.roster(count=2, rounds=1)
        self.call("start_round", expected_round=0)
        pair = self.pairs()[0]
        ticket = self.conn.execute("SELECT match_id FROM tournament_pairings WHERE id=?", (pair[0],)).fetchone()[0]
        accounts.handle_match(self.conn, {"action": "create", "match_id": ticket, "players": list(pair[1:3]), "mode": "casual", "deck_signatures": admit(self.conn, self.competition_id, pair[1:3])})
        accounts.handle_match(self.conn, {"action": "start", "match_id": ticket})
        self.call("schedule", task="start_round", due_at=int(time.time()) + 100, expected_round=1)
        self.assertTrue(self.call("update_description", description="比赛中也可修改")["ok"])
        self.assertTrue(self.call("delete")["ok"])
        for table in ("tournament_members", "tournament_rounds", "tournament_pairings", "tournament_schedules"):
            self.assertEqual(self.conn.execute(f"SELECT COUNT(*) FROM {table} WHERE tournament_id=?", (self.competition_id,)).fetchone()[0], 0)
        self.assertEqual(self.conn.execute("SELECT status FROM rating_matches WHERE match_id=?", (ticket,)).fetchone()[0], "cancelled")
        self.assertFalse(accounts.handle_match(self.conn, {"action": "settle", "match_id": ticket, "winner": 0})["ok"])
        self.assertFalse(competitions.handle_game(self.conn, {"action": "lookup", "match_id": ticket, "player_id": pair[1]})["ok"])
        competitions.tick(self.conn, int(time.time()) + 200)
        self.assertFalse(self.call("detail")["ok"])

    def test_invalid_formats_do_not_create_or_modify_competitions(self):
        for value in (True, 0, 8, "3", [], 1.5):
            self.assertFalse(self.call("create", title="非法赛制", game_format=value, start_at=self.start_at)["ok"])
            self.assertFalse(self.call("configure", game_format=value)["ok"])
        self.assertEqual(self.call("detail")["tournament"]["game_format"], 2)


class MatchingTests(unittest.TestCase):
    def test_general_matching_agrees_with_exhaustive_small_graphs(self):
        rng = random.Random(8215)

        def exhaustive(graph, remaining):
            if not remaining:
                return True
            a = min(remaining)
            return any(exhaustive(graph, remaining - {a, b}) for b in graph[a] if b in remaining)

        for n in (2, 4, 6, 8):
            for _ in range(150):
                graph = [[] for i in range(n)]
                for a in range(n):
                    for b in range(a + 1, n):
                        if rng.random() < 0.45:
                            graph[a].append(b)
                            graph[b].append(a)
                result = perfect_matching(graph)
                self.assertEqual(result is not None, exhaustive(graph, set(range(n))))
                if result is not None:
                    self.assertEqual(len({v for pair in result for v in pair}), n)
                    self.assertTrue(all(b in graph[a] for a, b in result))


if __name__ == "__main__":
    unittest.main()
