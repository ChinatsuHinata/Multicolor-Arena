"""Current daily assignment, evidence, claim/reroll and season contracts."""
import copy
import hashlib
import http.client
import json
import sqlite3
import sys
import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store as accounts
import task_store as tasks
from support.tournament_decks import admit

NOW = int(datetime(2026, 10, 24, 8, tzinfo=tasks.CHINA_TIME).timestamp())


class DailyTasks(unittest.TestCase):
    def setUp(self):
        scratch = Path(__file__).resolve().parents[1] / "work" / "task-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="TEST_ONLY_tasks_", dir=scratch)
        self.path = Path(self.temp.name) / "players.sqlite3"
        self.clock = patch("time.time", return_value=NOW)
        self.clock.start()
        self.conn = accounts.database(self.path)
        for player in range(1, 15):
            self.conn.execute("INSERT INTO players(id,username,password_salt,password_hash,created_at) VALUES(?,?,?,?,0)",
                              (player, f"TEST_ONLY_{player}", b"salt", b"hash"))
        self.token = "a" * 64
        self.conn.execute("INSERT INTO sessions(player_id,platform,token_hash,device,issued_at) VALUES(1,'pc',?,?,?)",
                          (hashlib.sha256(self.token.encode()).digest(), "d" * 32, NOW))
        self.conn.commit()
        self.number = 0
        self.assign(0, "ranked_win")
        self.assign(1, "player_damage")
        self.assign(2, "ranked_wins")

    def tearDown(self):
        self.conn.close()
        self.clock.stop()
        self.temp.cleanup()

    def definition(self, group, variant=None):
        entry = next(item for item in tasks.CATALOGUE if item["group"] == group)
        def choose(values):
            return next(item for item in values if item.get("key") == variant) if variant and "key" in values[0] else values[0]
        with patch.object(tasks.secrets, "choice", side_effect=choose):
            return tasks.choose_definition(entry["tier"], [item["group"] for item in tasks.CATALOGUE if item["group"] != group])

    def assign(self, slot, group, variant=None, progress=0):
        with self.conn:
            tasks.ensure_daily(self.conn, 1, tasks.today())
            tasks.put_assignment(self.conn, 1, tasks.today(), slot, self.definition(group, variant))
            self.conn.execute("UPDATE task_daily_assignments SET progress=? WHERE player_id=1 AND day=? AND slot=?", (progress, tasks.today(), slot))

    def state(self, player=1):
        return tasks.snapshot(self.conn, player)

    def row(self, slot):
        return self.state()["daily"]["tasks"][int(slot)]

    def request(self, action, slot=0, **extra):
        row = self.row(slot)
        return accounts.handle(self.conn, {"action": action, "token": self.token, "day": tasks.today(), "slot": slot, "task_id": row["id"], **extra})

    def match(self, winner=0, mode="ranked", stats=None, evidence=None, settle=True, deck_signatures=None):
        self.number += 1
        base = {"match_id": f"{self.number:032x}"}
        self.assertTrue(accounts.handle_match(self.conn, {**base, "action": "create", "players": [1, 2], "mode": mode, "deck_signatures": deck_signatures})["ok"])
        self.assertTrue(accounts.handle_match(self.conn, {**base, "action": "start"})["ok"])
        if not settle:
            return base
        if stats is not None:
            evidence = {"version": 1, "players": [stats, {}]}
        result = accounts.handle_match(self.conn, {**base, "action": "settle", "winner": winner, "evidence": evidence})
        self.assertTrue(result["ok"])
        return base

    def test_manual_claim_atomic_idempotent_authenticated(self):
        self.assertEqual([r["reward"] for r in self.state()["daily"]["tasks"]], [1, 1, 3])
        self.assertEqual(self.state()["server_time"], NOW)
        self.assertFalse(self.request("task_claim")["ok"])
        game = self.match(stats={"player_damage": 40})
        self.assertEqual(self.state()["coins"], 0)
        self.assertEqual(self.state()["daily"]["claimable"], 2)
        self.assertTrue(self.request("task_claim", player_id=2, coins=99999, reward=99999)["ok"])
        self.assertEqual(self.state()["coins"], 1)
        self.assertEqual(self.state(2)["coins"], 0)
        self.assertTrue(self.request("task_claim")["ok"])
        self.assertEqual(self.state()["coins"], 1)
        self.assertFalse(self.request("task_claim", token="bad")["ok"])
        self.assertFalse(self.request("task_reroll")["ok"])
        before = self.state()
        self.assertTrue(accounts.handle_match(self.conn, {**game, "action": "settle", "winner": 0})["ok"])
        self.assertEqual(before, self.state())
        self.conn.close()
        self.conn = accounts.database(self.path)
        self.assertEqual(before, self.state())

    def test_advanced_rewards_and_daily_cap(self):
        for _ in range(3):
            self.match(stats={"player_damage": 20})
        self.assertEqual(self.state()["daily"]["claimable"], 3)
        self.assertEqual(self.state()["coins"], 0)
        for slot in range(3):
            self.assertTrue(self.request("task_claim", slot)["ok"])
            self.assertTrue(self.request("task_claim", slot)["ok"])
        self.assertEqual(self.state()["coins"], 5)
        self.assertEqual(self.state()["daily"]["claimable"], 0)
        self.match()
        self.assertEqual(self.state()["coins"], 5)

    def test_beijing_six_boundary_and_stale_actions(self):
        boundary = int(datetime(2026, 10, 25, 6, tzinfo=tasks.CHINA_TIME).timestamp())
        self.assertEqual(tasks.today(boundary - 1), "2026-10-24")
        self.assertEqual(tasks.today(boundary), "2026-10-25")
        self.assertEqual(tasks.reset_at("2026-10-24"), boundary)
        old = self.row(0)
        with patch("time.time", return_value=boundary - 1):
            self.match()
            self.assertTrue(self.row(0)["completed"])
        with patch("time.time", return_value=boundary):
            answer = self.request("task_claim", day="2026-10-24", task_id=old["id"])
            self.assertFalse(answer["ok"])
            self.assertEqual(answer["tasks"]["daily"]["day"], "2026-10-25")
            self.assertTrue(all(r["progress"] == 0 for r in answer["tasks"]["daily"]["tasks"]))
            self.assertEqual(self.state()["coins"], 0)
        self.assertEqual(tasks.today(tasks.FIRST_SEASON_END), "2026-11-30")

    def test_group_weighting_and_catalogue_freeze(self):
        calls = []
        def choose(values):
            calls.append(copy.deepcopy(values))
            return next(item for item in values if item.get("group") == "color_win") if len(calls) == 1 else values[0]
        with patch.object(tasks.secrets, "choice", side_effect=choose):
            definition = tasks.choose_definition("basic")
        self.assertEqual(len(calls[0]), len([e for e in tasks.CATALOGUE if e["tier"] == "basic"]))
        self.assertEqual(len(calls[1]), 5)
        self.assertEqual(definition["conditions"]["leader_color"], "黑")
        self.state(2)
        state = self.state()
        with patch.object(tasks, "CATALOGUE", []):
            self.assertEqual(state, self.state())
            self.match(stats={"player_damage": 10})
            self.assertEqual(self.row(1)["progress"], 10)
            self.assertFalse(self.request("task_reroll")["ok"])

    def test_card_names_and_detail_references_match_real_cards(self):
        cards_dir = Path(__file__).resolve().parents[1] / "cards"
        for entry in tasks.CATALOGUE:
            for variant in entry.get("variants", [None]):
                definition = self.definition(entry["group"], variant["key"] if variant else None)
                for reference in definition["card_refs"]:
                    card = json.loads((cards_dir / (reference["id"] + ".json")).read_text(encoding="utf-8"))
                    self.assertEqual(reference["name"], card["名称"])
                    self.assertIn(reference.get("text", reference["name"]), definition["title"] + definition["detail"])
                self.assertNotIn("cards", definition["conditions"])
                self.assertNotIn("card_refs", definition["conditions"])
                self.assertNotIn("card_labels", definition["conditions"])
        self.assign(2, "special_win", "coin")
        coin_task = self.row(2)
        self.assertIn("玩家任选一", coin_task["title"])
        self.assertEqual(coin_task["card_refs"][0], {"id": "character-kmo-001", "name": "彼岸的渡者「小野冢小町」", "text": "投钱"})
        self.assertEqual(len(coin_task["card_refs"]), 3)
        komachi = json.loads((cards_dir / "character-kmo-001.json").read_text(encoding="utf-8"))
        self.assertEqual(komachi["类别"], "自机")
        self.assertEqual(sum(komachi["费用"].values()), 5)
        self.assign(0, "spell_counters")
        references = self.row(0)["card_refs"]
        self.assertEqual(references[0], {"id": "spell-fdn-069", "name": "「青ノ花」"})
        self.assertNotIn("费用", self.row(0)["detail"])
        flower = json.loads((cards_dir / "spell-fdn-069.json").read_text(encoding="utf-8"))
        self.assertEqual(flower["费用"], {"蓝": 2})
        self.assign(2, "leader_win", "tokiko")
        self.match(stats={"leader_id": "character-mar-025", "leader_character": "朱鹭子"})
        self.assertFalse(self.row(2)["completed"])

    def test_reroll_once_resets_excludes_groups_and_retries(self):
        self.match(stats={"player_damage": 30})
        old = self.row(1)
        old_groups = {r["group"] for r in self.state()["daily"]["tasks"]}
        self.assertTrue(self.request("task_reroll", 1)["ok"])
        current = self.row(1)
        self.assertNotIn(current["group"], old_groups)
        self.assertNotEqual(current["id"], old["id"])
        self.assertEqual(current["progress"], 0)
        self.assertTrue(current["rerolled"])
        self.assertTrue(self.request("task_reroll", 1, task_id=old["id"])["ok"])
        self.assertEqual(current, self.row(1))
        self.assertFalse(self.request("task_reroll", 1)["ok"])
        self.assertFalse(self.request("task_claim", 1, task_id=old["id"])["ok"])

    def test_sum_max_and_mode_rules(self):
        self.assign(2, "healthy_win")
        self.match(stats={"player_damage": 12, "final_life": 31})
        self.match(stats={"player_damage": 10, "final_life": 25})
        self.match(mode="casual", stats={"player_damage": 18, "final_life": 100})
        self.assertEqual(self.row(1)["progress"], 40)
        self.assertEqual(self.row(2)["progress"], 31)
        self.assertFalse(self.row(2)["completed"])
        self.match(stats={"final_life": 32})
        self.match(winner=1, stats={"final_life": 50})
        self.assertEqual(self.row(2)["progress"], 32)
        self.assertTrue(self.row(2)["completed"])

    def test_ranked_wins_accumulate_across_losses(self):
        self.match(); self.match(mode="casual", winner=1); self.match()
        self.assertEqual(self.row(2)["progress"], 2)
        self.match(winner=1)
        self.match(mode="casual"); self.match(mode="exploration"); self.match(mode="exploration_random")
        self.assertEqual(self.row(2)["progress"], 2)
        self.assertFalse(self.row(2)["completed"])
        self.match(); self.match(winner=1)
        self.assertEqual(self.row(2)["progress"], 3)
        self.assertTrue(self.row(2)["completed"])

    def test_advanced_pool_and_player_choices(self):
        expected = {
            "ranked_wins": 0, "special_win": 3,
            "mill_win": 0, "leader_win": 4,
            "signature_spell": 3,
            "healthy_win": 0, "overkill_win": 0, "no_combat_win": 0,
        }
        entries = [entry for entry in tasks.CATALOGUE if entry["tier"] == "advanced"]
        self.assertEqual({entry["group"] for entry in entries}, set(expected))
        for entry in entries:
            with self.subTest(group=entry["group"]):
                self.assertNotIn("variants", entry)
                self.assertEqual(len(entry["conditions"].get("any_of", [])), expected[entry["group"]])
                calls = []
                def choose(values):
                    calls.append(values)
                    return entry if "group" in values[0] else values[0]
                with patch.object(tasks.secrets, "choice", side_effect=choose):
                    definition = tasks.choose_definition("advanced")
                self.assertEqual(calls[0], entries, "Outer groups share one draw")
                self.assertEqual(len(calls), 1, "The player can satisfy any listed choice without another random draw")
                self.assertEqual(definition["reward"], 3)
                self.assertEqual(definition["conditions"]["mode"], "ranked")
                self.assertTrue(definition["conditions"]["won"])

    def test_every_catalogue_counter_and_variant(self):
        counts = {"player_damage": 40, "units_destroyed": 10, "items_barriers_removed": 4,
                  "fast_spells": 15, "non_spells": 10, "character_spells": 12, "unit_cards": 24,
                  "tokens_created": 20, "spell_counters": 8, "death_triggers": 10, "life_recovered": 20}
        for group, value in counts.items():
            self.assign(1, group)
            self.match(mode="casual", stats={group: value})
            self.assertTrue(self.row(1)["completed"], group)
        for color in ("黑", "绿", "红", "蓝", "黄"):
            self.assign(1, "color_win", color)
            self.match(stats={"leader_colors": [color]})
            self.assertTrue(self.row(1)["completed"], color)
        self.assign(1, "exploration_win")
        self.match(mode="ranked")
        self.assertEqual(self.row(1)["progress"], 0)
        self.match(mode="exploration"); self.match(mode="exploration_random")
        self.assertEqual(self.row(1)["progress"], 2)
        self.assign(1, "ranked_matches")
        self.match(winner=1); self.match(); self.match(winner=1)
        self.assertTrue(self.row(1)["completed"])
        for key, field in (("tokiko", {"leader_id": "character-htk-002"}), ("cirno", {"leader_id": "character-lof-001"}), ("byakuren", {"leader_id": "character-fdf-ex03"}), ("kanako", {"leader_id": "82"})):
            self.assign(2, "leader_win", key)
            self.match(stats=field)
            self.assertTrue(self.row(2)["completed"], key)
            self.assign(2, "leader_win")
            self.match(winner=1, stats=field)
            self.match(mode="casual", stats=field)
            self.assertFalse(self.row(2)["completed"])
        for reason in ("coin", "gate"):
            self.assign(2, "special_win", reason)
            self.match(stats={"win_reason": reason})
            self.assertTrue(self.row(2)["completed"], reason)
        self.assign(2, "mill_win")
        self.match(winner=1, stats={"enemy_final_deck": 0})
        self.match(mode="casual", stats={"enemy_final_deck": 5})
        self.match(stats={"enemy_final_deck": 6})
        self.assertEqual(self.row(2)["progress"], 0)
        self.match(stats={"win_reason": "normal", "enemy_final_deck": 5})
        self.assertEqual(self.row(2)["progress"], 1)
        self.assertTrue(self.row(2)["completed"])

    def test_low_enemy_deck_win_boundaries_and_decisive_game(self):
        self.assign(2, "mill_win")
        for size in (6, 50, -1, 1.5, True, "5", None):
            self.match(stats={"enemy_final_deck": size})
        self.match(stats={"win_reason": "mill"})
        self.match(stats={"enemy_final_deck": 0, "final_game": {"enemy_final_deck": 6}})
        self.match(stats={"enemy_final_deck": 0, "final_game": {}})
        self.match(stats={"enemy_final_deck": 0, "final_game": None})
        for mode in ("casual", "exploration", "exploration_random"):
            self.match(mode=mode, stats={"enemy_final_deck": 0})
        self.match(winner=1, stats={"enemy_final_deck": 0})
        self.assertEqual(self.row(2)["progress"], 0)
        for size, reason in ((0, "mill"), (4, "normal"), (5, "surrender")):
            with self.subTest(size=size, reason=reason):
                self.assign(2, "mill_win")
                self.match(stats={"enemy_final_deck": 50, "final_game": {"enemy_final_deck": size, "win_reason": reason}})
                self.assertEqual(self.row(2)["progress"], 1)
                self.assertTrue(self.row(2)["completed"])
        self.assertEqual(self.row(2)["reward"], 3)
        self.assertTrue(self.request("task_claim", 2)["ok"])
        self.assertTrue(self.request("task_claim", 2)["ok"])
        self.assertEqual(self.state()["coins"], 3)

    def test_low_enemy_deck_win_upgrades_unclaimed_tasks(self):
        legacy = self.definition("mill_win")
        legacy.update(version=4, title="段位匹配磨牌胜利 1 次")
        legacy["conditions"] = {"mode": "ranked", "won": True, "win_reason": "mill"}
        for progress in (0, 1):
            self.assign(2, "mill_win", progress=progress)
            current = self.row(2)
            with self.conn:
                self.conn.execute("UPDATE task_daily_assignments SET definition=?,rerolled=1,previous_id=? WHERE player_id=1 AND day=? AND slot=2",
                                  (json.dumps(legacy), "c" * 16, tasks.today()))
            upgraded = self.row(2)
            self.assertEqual(upgraded["id"], current["id"])
            self.assertEqual(upgraded["progress"], progress)
            self.assertEqual(upgraded["completed"], progress == 1)
            self.assertTrue(upgraded["rerolled"])
            frozen, previous = self.conn.execute("SELECT definition,previous_id FROM task_daily_assignments WHERE player_id=1 AND day=? AND slot=2", (tasks.today(),)).fetchone()
            self.assertEqual(json.loads(frozen)["conditions"], {"mode": "ranked", "won": True, "enemy_deck_max": 5})
            self.assertEqual(previous, "c" * 16)
            self.assertEqual(upgraded, self.row(2), "Migration is idempotent")
        self.assertTrue(self.request("task_claim", 2)["ok"])
        self.assertEqual(self.state()["coins"], 3)
        with self.conn:
            self.conn.execute("UPDATE task_daily_assignments SET definition=? WHERE player_id=1 AND day=? AND slot=2", (json.dumps(legacy), tasks.today()))
        self.assertEqual(self.row(2)["title"], legacy["title"], "Claimed tasks stay frozen")

    def test_combined_removal_task_progress_and_legacy_evidence(self):
        groups = [entry["group"] for entry in tasks.CATALOGUE]
        self.assertEqual(groups.count("items_barriers_removed"), 1)
        self.assertNotIn("items_destroyed", groups)
        self.assertNotIn("barriers_destroyed", groups)
        self.assign(1, "items_barriers_removed")
        self.assertEqual(self.row(1)["target"], 4)
        self.assertEqual(self.row(1)["reward"], 1)
        for mode in ("ranked", "casual", "exploration", "exploration_random"):
            self.match(mode=mode, winner=1, stats={"items_barriers_removed": 1, "items_destroyed": 1, "barriers_destroyed": 1})
        self.assertEqual(self.row(1)["progress"], 4, "Do not add legacy counters to the new aggregate")
        self.assertTrue(self.row(1)["completed"])
        self.assertTrue(self.request("task_claim", 1)["ok"])
        self.assertTrue(self.request("task_claim", 1)["ok"])
        self.assertEqual(self.state()["coins"], 1)
        self.assign(1, "items_barriers_removed")
        for stats in ({}, {"items_destroyed": 3}, {"items_barriers_removed": -1, "items_destroyed": 4, "barriers_destroyed": 4},
                      {"items_destroyed": True, "barriers_destroyed": 4}):
            self.match(stats=stats)
        self.assertEqual(self.row(1)["progress"], 0, "Missing or malformed evidence must not fabricate progress")
        self.match(stats={"items_destroyed": 1, "barriers_destroyed": 2})
        self.assertEqual(self.row(1)["progress"], 3)
        self.assertFalse(self.row(1)["completed"])
        self.match(stats={"items_barriers_removed": 1})
        self.assertTrue(self.row(1)["completed"])

    def test_existing_removal_tasks_upgrade_without_losing_slot_state(self):
        originals = []
        for slot, group in enumerate(("items_destroyed", "barriers_destroyed")):
            legacy = self.definition("items_barriers_removed")
            legacy.update(group=group, key=group, metric=group, target=5 if slot == 0 else 4, version=3)
            with self.conn:
                identity = tasks.put_assignment(self.conn, 1, tasks.today(), slot, legacy, rerolled=True, previous_id="b" * 16)
                self.conn.execute("UPDATE task_daily_assignments SET progress=? WHERE player_id=1 AND day=? AND slot=?", (slot + 2, tasks.today(), slot))
            originals.append(identity)
        rows = self.state()["daily"]["tasks"]
        for slot in range(2):
            self.assertEqual(rows[slot]["id"], originals[slot])
            self.assertEqual(rows[slot]["group"], "items_barriers_removed")
            self.assertEqual(rows[slot]["progress"], slot + 2)
            self.assertEqual(rows[slot]["target"], 4)
            self.assertTrue(rows[slot]["rerolled"])
            self.assertEqual(self.conn.execute("SELECT group_id,previous_id FROM task_daily_assignments WHERE player_id=1 AND day=? AND slot=?", (tasks.today(), slot)).fetchone(), ("items_barriers_removed", "b" * 16))
        self.assertEqual(rows, self.state()["daily"]["tasks"], "Migration is idempotent")
        self.match(stats={"items_barriers_removed": 1})
        self.assertFalse(self.row(0)["completed"])
        self.assertTrue(self.row(1)["completed"])
        self.match(stats={"items_barriers_removed": 1})
        for slot in range(2):
            self.assertTrue(self.request("task_claim", slot)["ok"])
            self.assertTrue(self.request("task_claim", slot)["ok"])
        self.assertEqual(self.state()["coins"], 2)

    def test_claimed_removal_task_stays_frozen_and_excludes_merged_rerolls(self):
        legacy = self.definition("items_barriers_removed")
        legacy.update(group="items_destroyed", key="items_destroyed", metric="items_destroyed", target=5, version=3)
        with self.conn:
            tasks.put_assignment(self.conn, 1, tasks.today(), 0, legacy)
            self.conn.execute("UPDATE task_daily_assignments SET claimed=1,progress=5 WHERE player_id=1 AND day=? AND slot=0", (tasks.today(),))
        self.assertEqual(self.row(0)["group"], "items_destroyed")
        self.assertEqual(self.row(0)["target"], 5)
        candidates = []
        def choose(values):
            candidates.extend(values)
            return values[0]
        with patch.object(tasks.secrets, "choice", side_effect=choose):
            self.assertTrue(self.request("task_reroll", 1)["ok"])
        self.assertNotIn("items_barriers_removed", [entry.get("group") for entry in candidates])
        with patch("time.time", return_value=tasks.reset_at(tasks.today())):
            groups = [row["group"] for row in self.state()["daily"]["tasks"]]
            self.assertEqual(len(groups), len(set(groups)))
            self.assertNotIn("items_destroyed", groups)
            self.assertNotIn("barriers_destroyed", groups)

    def test_signature_spell_requires_cast_in_same_ranked_win(self):
        for card in ("118", "121", "spell-fdf-008"):
            with self.subTest(card=card):
                self.assign(2, "signature_spell", card)
                self.match(winner=1, stats={"cast_cards": {card: 1}})
                self.assertEqual(self.row(2)["progress"], 0, "A losing cast must not count")
                self.match(stats={"cast_cards": {}})
                self.assertEqual(self.row(2)["progress"], 0, "A later win cannot complete an earlier losing cast")
                self.match(mode="casual", stats={"cast_cards": {card: 1}})
                self.assertEqual(self.row(2)["progress"], 0, "Only ranked wins count")
                # A drawn game may contribute to match totals, but the selected
                # spell must have been cast in the final, victorious game itself.
                self.match(stats={"cast_cards": {card: 1}, "final_game": {"cast_cards": {}}})
                self.assertEqual(self.row(2)["progress"], 0, "An earlier drawn game cannot supply the winning cast")
                self.match(stats={"cast_cards": {card: 2}, "final_game": {"cast_cards": {card: 1}}})
                self.assertEqual(self.row(2)["progress"], 1)
                self.assertTrue(self.row(2)["completed"])
                self.assertEqual(self.state()["coins"], 0, "Completion still requires manual claim")
                self.assign(2, "signature_spell", card)
                self.match(stats={"cast_cards": {card: 1}})
                self.assertTrue(self.row(2)["completed"])

    def test_choices_count_once_and_upgrade_current_unclaimed_tasks(self):
        self.assign(2, "special_win")
        self.match(stats={"win_reason": "coin", "royal_flare_kill": True})
        self.assertEqual(self.row(2)["progress"], 1)
        current = self.row(2)
        legacy = self.definition("special_win")
        legacy.update(version=2, key="special_win:coin", title="投钱胜利")
        legacy["conditions"] = {"mode": "ranked", "won": True, "win_reason": "coin"}
        with self.conn:
            self.conn.execute("UPDATE task_daily_assignments SET definition=?,rerolled=1 WHERE player_id=1 AND day=? AND slot=2", (json.dumps(legacy), tasks.today()))
        upgraded = self.row(2)
        self.assertEqual(upgraded["id"], current["id"])
        self.assertEqual(upgraded["progress"], 1)
        self.assertTrue(upgraded["rerolled"])
        self.assertIn("玩家任选一", upgraded["title"])
        self.assertTrue(self.request("task_claim", 2)["ok"])
        self.assertEqual(self.state()["coins"], 3)

    def test_royal_kill_requires_decisive_game_evidence(self):
        self.assign(2, "special_win", "royal")
        self.match(stats={"player_damage": 40, "royal_flare_damage": 40})
        self.match(stats={"royal_flare_kill": False})
        self.match(stats={"royal_flare_kill": 1})
        self.match(winner=1, stats={"royal_flare_kill": True})
        self.match(mode="casual", stats={"royal_flare_kill": True})
        self.match(stats={"royal_flare_kill": True, "final_game": {"royal_flare_kill": False}})
        self.assertFalse(self.row(2)["completed"])
        self.match(stats={"player_damage": 70, "royal_flare_damage": 40,
                          "final_game": {"player_damage": 30, "royal_flare_damage": 5, "royal_flare_kill": True}})
        self.assertTrue(self.row(2)["completed"])
        self.assign(2, "special_win", "royal")
        self.match(stats={"royal_flare_kill": True})
        self.assertTrue(self.row(2)["completed"])

    def test_no_unit_combat_win_has_no_enemy_life_requirement(self):
        self.assign(2, "no_combat_win")
        self.match()
        self.match(stats={"enemy_final_life": -9, "unit_combat_player_damage": 1})
        self.match(stats={"unit_combat_player_damage": True})
        self.match(winner=1, stats={"unit_combat_player_damage": 0})
        self.match(mode="casual", stats={"unit_combat_player_damage": 0})
        self.match(stats={"unit_combat_player_damage": 0, "final_game": {"unit_combat_player_damage": 1}})
        self.assertFalse(self.row(2)["completed"])
        self.match(stats={"unit_combat_player_damage": 7, "final_game": {"enemy_final_life": -5, "unit_combat_player_damage": 0}})
        self.assertTrue(self.row(2)["completed"])
        for life in (0, 8, -9, None):
            with self.subTest(enemy_life=life):
                self.assign(2, "no_combat_win")
                self.match(stats={"enemy_final_life": life, "unit_combat_player_damage": 0})
                self.assertTrue(self.row(2)["completed"])

    def test_last_game_real_overkill(self):
        self.assign(2, "overkill_win")
        self.match(stats={"enemy_final_life": -20, "overkill": 0})
        self.assertEqual(self.row(2)["progress"], 0)
        self.match(stats={"enemy_final_life": -8, "overkill": 30})
        self.assertEqual(self.row(2)["progress"], 8)
        self.match(stats={"enemy_final_life": -12, "overkill": 12})
        self.assertEqual(self.row(2)["progress"], 12)

    def test_invalid_counters_and_public_forgery(self):
        for bad in (True, -1, 1.5, "40", None, 10**20, 10**400, float("inf"), float("nan")):
            self.match(stats={"player_damage": bad})
            self.assertEqual(self.row(1)["progress"], 0)
        self.match(evidence={"version": 1.0, "players": [{"player_damage": 40.0}, {}]})
        self.assertEqual(self.row(1)["progress"], 40)
        self.assertTrue(self.request("task_claim", slot=1.0)["ok"])
        before = self.state()
        for action in ("tasks", "verify", "settle", "close_season", "set_coins", "task_claim"):
            accounts.handle(self.conn, {"action": action, "token": self.token, "player_id": 2,
                "coins": 9999, "daily": {"progress": 9999}, "evidence": {"version": 1, "players": [{"player_damage": 9999}, {}]}, "now": tasks.FIRST_SEASON_END})
        self.assertEqual(before, self.state())

    def test_cancelled_tournaments_and_transaction_rollback(self):
        base = self.match(settle=False)
        accounts.handle_match(self.conn, {**base, "action": "cancel"})
        self.assertFalse(accounts.handle_match(self.conn, {**base, "action": "settle", "winner": 0})["ok"])
        tournament = self.conn.execute("INSERT INTO tournaments(owner_id,title,description,phase,created_at,round_number) VALUES(1,'TEST_ONLY_tasks','','running',?,1)", (NOW,)).lastrowid
        self.conn.execute("INSERT INTO tournament_pairings(tournament_id,round_number,table_number,player_a,player_b,match_id) VALUES(?,1,1,1,2,?)", (tournament, f"{self.number + 1:032x}"))
        self.conn.commit()
        self.match(mode="casual", stats={"player_damage": 99}, deck_signatures=admit(self.conn, tournament, [1, 2]))
        self.assertEqual(self.row(1)["progress"], 0)
        pending = self.match(settle=False)
        before, rank = self.state(), accounts.player_rank(self.conn, 1)
        original = tasks.record_match
        def fail(*args, **kwargs):
            original(*args, **kwargs)
            raise ValueError("TEST_ONLY rollback")
        with patch.object(tasks, "record_match", side_effect=fail), self.assertRaises(ValueError):
            accounts.handle_match(self.conn, {**pending, "action": "settle", "winner": 0})
        self.assertEqual(before, self.state())
        self.assertEqual(rank, accounts.player_rank(self.conn, 1))
        self.assertEqual(self.conn.execute("SELECT status FROM rating_matches WHERE match_id=?", (pending["match_id"],)).fetchone()[0], "playing")

    def test_concurrent_claim_and_reroll(self):
        self.match()
        payload = {"day": tasks.today(), "slot": 0, "task_id": self.row(0)["id"]}
        def race(action, request):
            local = sqlite3.connect(self.path)
            try:
                return tasks.mutate(local, 1, action, request)
            finally:
                local.close()
        with ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(lambda _: race("task_claim", payload), range(2)))
        self.assertEqual(self.state()["coins"], 1)
        payload = {"day": tasks.today(), "slot": 1, "task_id": self.row(1)["id"]}
        with ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(lambda _: race("task_reroll", payload), range(2)))
        self.assertTrue(self.row(1)["rerolled"])
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM task_rewards WHERE category='daily'").fetchone()[0], 1)

    def test_http_match_accepts_full_evidence_and_preserves_other_limits(self):
        class TestHandler(accounts.Handler):
            pass
        server = accounts.AccountHTTPServer(("127.0.0.1", 0), TestHandler)
        def serve():
            TestHandler.conn = accounts.database(self.path)
            try:
                server.serve_forever(poll_interval=0.01)
            finally:
                TestHandler.conn.close()
        worker = threading.Thread(target=serve, daemon=True)
        worker.start()
        def post(path, value):
            body = value if isinstance(value, bytes) else json.dumps(value).encode("utf-8")
            connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=5)
            try:
                limit = 65536 if path == "/match" else 2048
                if len(body) > limit:
                    # The server rejects the declared length before reading the body.
                    # Sending that body races its close and causes WinError 10053 on Windows.
                    connection.putrequest("POST", path)
                    connection.putheader("Content-Type", "application/json")
                    connection.putheader("Content-Length", str(len(body)))
                    connection.endheaders()
                else:
                    connection.request("POST", path, body, {"Content-Type": "application/json"})
                response = connection.getresponse()
                data = response.read()
                return response.status, json.loads(data) if response.status == 200 else data
            finally:
                connection.close()
        try:
            base = {"match_id": "e" * 32}
            for action in ("create", "start"):
                status, answer = post("/match", {**base, "action": action, "players": [1, 2], "mode": "ranked"})
                self.assertEqual(status, 200)
                self.assertTrue(answer["ok"])
            stats = {"player_damage": 40, "royal_flare_damage": 40, "unit_combat_player_damage": 0,
                     "final_life": 42, "enemy_final_life": -10, "overkill": 10, "win_reason": "normal",
                     "leader_id": "character-lof-001", "leader_character": "琪露诺", "leader_colors": ["蓝", "绿"],
                     "cast_cards": {f"spell-probe-{index:03}": 1 for index in range(90)}}
            evidence = {"version": 1, "players": [{**stats, "final_game": copy.deepcopy(stats)} for _ in range(2)]}
            payload = {**base, "action": "settle", "winner": 0, "evidence": evidence}
            self.assertGreater(len(json.dumps(payload).encode()), 2048)
            self.assertLess(len(json.dumps(evidence).encode()), 32768)
            for _ in range(2):
                status, answer = post("/match", payload)
                self.assertEqual(status, 200)
                self.assertTrue(answer["ok"])
            self.assertEqual(self.row(1)["progress"], 40)
            self.assertEqual(self.state()["coins"], 0)
            saved = self.conn.execute("SELECT evidence FROM task_match_evidence WHERE match_id=?", (base["match_id"],)).fetchone()
            self.assertEqual(json.loads(saved[0]), evidence)
            self.assertEqual(post("/account", payload)[0], 413)
            self.assertEqual(post("/session", payload)[0], 413)
            self.assertEqual(post("/match", b" " * 65537)[0], 413)
        finally:
            server.shutdown()
            worker.join(timeout=5)
            server.server_close()
        self.assertFalse(worker.is_alive())

    def test_migration_preserves_wallet_and_rewards(self):
        self.conn.execute("INSERT INTO task_wallets VALUES(1,17)")
        self.conn.execute("INSERT INTO task_rewards VALUES(1,'daily',?,'win',1,?)", (tasks.today(), NOW))
        self.conn.execute("UPDATE players SET rank_step=8,elo=1500 WHERE id=1")
        self.conn.commit(); self.conn.close()
        self.conn = accounts.database(self.path)
        self.assertEqual(self.state()["coins"], 17)
        self.assertEqual(self.conn.execute("SELECT password_salt,password_hash,rank_step,elo FROM players WHERE id=1").fetchone(), (b"salt", b"hash", 8, 1500))
        self.assertEqual(len(self.state()["daily"]["tasks"]), 3)

    def test_final_season_tiers_deadline_restart_and_race(self):
        for player in range(1, 13):
            self.conn.execute("UPDATE players SET rank_step=11,elo=? WHERE id=?", (2000 - player * 10, player))
        self.conn.execute("UPDATE players SET elo=1980 WHERE id=3")
        self.conn.execute("UPDATE players SET elo=100 WHERE id=1")
        self.conn.commit()
        tasks.tick(self.conn, tasks.FIRST_SEASON_END - 1)
        self.assertEqual(self.state()["season"]["id"], 1)
        pending = self.match(settle=False)
        with patch("time.time", return_value=tasks.FIRST_SEASON_END):
            accounts.handle_match(self.conn, {**pending, "action": "settle", "winner": 0})
        expected_coins = [80, 60, 60, 40, 40, 40, 40, 40, 40, 40, 30, 30]
        for position, player in enumerate([2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 1], 1):
            self.assertEqual(self.state(player)["coins"], expected_coins[position - 1])
            self.assertEqual(self.state(player)["previous"]["position"], position)
        self.assertGreater(accounts.player_rank(self.conn, 2)["position"], 1)
        self.assertEqual(self.state(13)["coins"], 0)
        before = self.state()
        with self.conn:
            self.assertTrue(tasks.close_season(self.conn, 1)["already_settled"])
        self.assertEqual(before, self.state())
        self.conn.execute("UPDATE task_seasons SET ends_at=? WHERE id=2", (tasks.FIRST_SEASON_END + 3600,))
        self.conn.commit(); self.conn.close()
        def tick(_):
            local = sqlite3.connect(self.path)
            try:
                tasks.tick(local, tasks.FIRST_SEASON_END + 7200)
            finally:
                local.close()
        with ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(tick, range(2)))
        self.conn = accounts.database(self.path)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM task_rewards WHERE category='season'").fetchone()[0], 24)
        self.assertEqual(self.state()["previous"]["ended_at"], tasks.FIRST_SEASON_END + 3600)


if __name__ == "__main__":
    unittest.main(verbosity=2)
