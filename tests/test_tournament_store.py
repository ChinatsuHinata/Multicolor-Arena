"""Authenticated ownership, membership, check-in snapshots and persistence."""
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store as accounts
import tournament_store as tournaments


class TournamentTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = Path(self.directory.name) / "players.sqlite3"
        self.conn = accounts.database(self.path)
        self.logins = {}
        for index, name in enumerate(("bigcake", "first_player", "second_player")):
            credentials = {"username": name, "password": "password123!", "device": str(index) * 32}
            self.assertTrue(accounts.handle(self.conn, {"action": "register", **credentials})["ok"])
            self.logins[name] = accounts.handle(self.conn, {"action": "login", **credentials})
        self.start_at = int(time.time()) + 3600
        self.tournament_id = self.request("create", title="测试比赛", description="集合说明", start_at=self.start_at)["tournament"]["id"]

    def tearDown(self):
        self.conn.close()
        self.directory.cleanup()

    def request(self, action, username="bigcake", **data):
        account = accounts.verify(self.conn, self.logins[username]["token"])
        return tournaments.handle(self.conn, {"action": action, "id": getattr(self, "tournament_id", 0), **data}, account)

    def reach_start(self):
        self.clock = patch("tournament_store.time.time", return_value=self.start_at)
        self.clock.start()
        self.addCleanup(self.clock.stop)
        tournaments.tick(self.conn, self.start_at)

    def test_only_authenticated_owner_can_create_and_manage(self):
        for action in ("create", "open_checkin", "close_checkin"):
            self.assertFalse(self.request(action, "first_player", title="伪造", username_override="bigcake", owner_id=1)["ok"])
        accounts.handle(self.conn, {"action": "nickname", "token": self.logins["first_player"]["token"], "nickname": "bigcake"})
        self.assertFalse(self.request("create", "first_player", title="昵称伪装")["ok"])
        self.assertFalse(self.request("list", "first_player")["can_create"])
        self.assertTrue(self.request("list")["can_create"])

    def test_join_is_not_checkin_and_checkin_requires_membership(self):
        self.assertFalse(self.request("checkin", "first_player")["ok"])
        joined = self.request("join", "first_player")["tournament"]
        self.assertTrue(joined["joined"])
        self.assertFalse(joined["checked_in"])
        self.assertFalse(joined["in_roster"])
        self.assertFalse(self.request("checkin", "first_player")["ok"])
        self.assertFalse(self.request("open_checkin")["ok"])
        self.reach_start()
        self.assertTrue(self.request("open_checkin")["ok"])
        self.assertFalse(self.request("checkin", "second_player")["ok"])
        self.assertTrue(self.request("checkin", "first_player")["tournament"]["checked_in"])
        self.assertEqual(self.request("detail")["tournament"]["roster_count"], 0)

    def test_roster_contains_only_checked_in_members_and_survives_restart(self):
        self.request("join", "first_player")
        self.request("join", "second_player")
        self.reach_start()
        self.request("open_checkin")
        self.request("checkin", "first_player")
        closed = self.request("close_checkin")
        self.assertEqual(closed["tournament"]["phase"], "locked")
        self.assertEqual(closed["tournament"]["member_count"], 2)
        self.assertEqual(closed["tournament"]["roster_count"], 1)
        self.conn.close()
        self.conn = accounts.database(self.path)
        self.assertTrue(self.request("detail", "first_player")["tournament"]["in_roster"])
        self.assertFalse(self.request("detail", "second_player")["tournament"]["in_roster"])
        roster = self.request("detail", roster_only=True)
        self.assertEqual(len(roster["members"]), 1)
        self.assertTrue(roster["members"][0]["in_roster"])
        for action in ("join", "leave", "checkin", "open_checkin", "close_checkin"):
            self.assertFalse(self.request(action, "second_player" if action in ("join", "leave", "checkin") else "bigcake")["ok"])

    def test_duplicate_join_checkin_and_leave_clears_checkin_without_late_rejoin(self):
        self.request("join", "first_player")
        self.request("join", "first_player")
        self.reach_start()
        self.request("open_checkin")
        self.request("checkin", "first_player")
        self.request("checkin", "first_player")
        self.assertEqual(self.request("detail")["tournament"]["member_count"], 1)
        self.assertEqual(self.request("detail")["tournament"]["checkin_count"], 1)
        self.request("leave", "first_player")
        self.assertFalse(self.request("join", "first_player")["ok"])
        self.assertEqual(self.request("close_checkin")["tournament"]["roster_count"], 0)

    def test_invalid_input_and_expired_login(self):
        for data in ({"title": " "}, {"title": "字" * 41}, {"title": []}, {"title": "有效", "description": "字" * 2001}):
            self.assertFalse(self.request("create", start_at=self.start_at, **data)["ok"])
        for data in ({"id": True}, {"id": 1.5}, {"id": "1"}, {"id": -1}, {"id": 10**100}, {"id": 9999}):
            self.assertFalse(self.request("detail", **data)["ok"])
        for page in ([], "1", True, -1, float("inf"), 0.5):
            self.assertFalse(self.request("list", page=page)["ok"])
            self.assertFalse(self.request("detail", member_page=page)["ok"])
        self.assertFalse(self.request([], title="无效操作")["ok"])
        self.conn.execute("UPDATE sessions SET issued_at=?", (int(time.time()) - accounts.SESSION_LIFETIME - 1,))
        for action in ("list", "detail", "join", "checkin", "create", "close_checkin"):
            answer = self.request(action, title="会话过期")
            self.assertFalse(answer["ok"])
            self.assertTrue(answer["auth_required"])

    def test_pagination_and_response_privacy(self):
        for index in range(7):
            self.request("create", title=f"比赛 {index}", start_at=self.start_at)
        first = self.request("list")
        self.assertEqual(len(first["tournaments"]), tournaments.PAGE_SIZE)
        self.assertEqual(len(self.request("list", page=1)["tournaments"]), 2)
        self.assertEqual(first["pages"], 2)
        self.assertEqual(self.request("list", page=999)["page"], 1)
        for index in range(25):
            player_id = self.conn.execute("""INSERT INTO players(username,nickname,password_salt,password_hash,created_at)
                VALUES(?,?,?,?,?)""", (f"member_{index}", "昵称", b"", b"", 0)).lastrowid
            self.conn.execute("INSERT INTO tournament_members(tournament_id,player_id,joined_at) VALUES(?,?,?)",
                              (self.tournament_id, player_id, index))
        self.request("join", "first_player")
        detail = self.request("detail", "first_player")
        self.assertEqual(len(detail["members"]), tournaments.MEMBER_PAGE_SIZE)
        self.assertEqual(detail["member_pages"], 2)
        last = self.request("detail", "first_player", member_page=1)
        self.assertEqual(len(last["members"]), 6)
        self.assertTrue(last["members"][-1]["self"])
        for row in first["tournaments"] + detail["members"]:
            for secret in ("username", "player_id", "owner_id", "token", "elo"):
                self.assertNotIn(secret, row)

    def test_start_time_required_and_registration_closes_at_exact_deadline(self):
        self.assertFalse(self.request("create", title="缺少时间")["ok"])
        for value in (None, True, "123", 0, 1.5, int(time.time()), int(time.time()) + 367 * 86400):
            self.assertFalse(self.request("create", title="时间校验", start_at=value)["ok"])
        with patch("tournament_store.time.time", return_value=self.start_at - 1):
            preview = self.request("detail", "first_player")["tournament"]
            self.assertEqual(preview["description"], "集合说明")
            self.assertFalse(preview["joined"])
            self.assertTrue(self.request("join", "first_player")["ok"])
            self.assertFalse(self.request("checkin", "first_player")["ok"])
        with patch("tournament_store.time.time", return_value=self.start_at):
            self.assertFalse(self.request("join", "second_player")["ok"])
            self.assertFalse(self.request("checkin", "second_player")["ok"])
            self.assertTrue(self.request("checkin", "first_player")["ok"])
            self.assertEqual(self.request("detail")["tournament"]["phase"], "checkin")
            self.assertFalse(self.request("configure", start_at=self.start_at + 3600)["ok"])

    def test_description_permissions_validation_and_deletion_from_list(self):
        self.assertFalse(self.request("update_description", "first_player", description="冒充管理员")["ok"])
        for value in (None, [], "字" * 2001):
            self.assertFalse(self.request("update_description", description=value)["ok"])
        self.assertTrue(self.request("update_description", description="新规则\n奖励说明")["ok"])
        self.conn.close()
        self.conn = accounts.database(self.path)
        self.assertEqual(self.request("detail", "first_player")["tournament"]["description"], "新规则\n奖励说明")
        self.assertFalse(self.request("detail", "first_player")["tournament"]["joined"])
        self.assertFalse(self.request("delete", "first_player")["ok"])
        self.assertTrue(self.request("delete")["ok"])
        self.assertEqual(self.request("list")["total"], 0)
        for action in ("detail", "join", "checkin", "update_description", "delete"):
            self.assertFalse(self.request(action, description="已删除")["ok"])
        created = self.request("create", title="新比赛", start_at=self.start_at)
        self.assertNotEqual(created["tournament"]["id"], self.tournament_id)

    def test_existing_competitions_require_a_time_before_registration(self):
        self.conn.execute("ALTER TABLE tournaments DROP COLUMN game_format")
        self.conn.execute("ALTER TABLE tournaments DROP COLUMN start_at")
        self.conn.commit()
        self.conn.close()
        self.conn = accounts.database(self.path)
        migrated = self.request("detail")["tournament"]
        self.assertEqual(migrated["description"], "集合说明")
        self.assertEqual(migrated["game_format"], 2)
        self.assertEqual(migrated["start_at"], 0)
        self.assertFalse(self.request("join", "first_player")["ok"])
        self.assertTrue(self.request("configure", start_at=self.start_at)["ok"])
        self.assertTrue(self.request("join", "first_player")["ok"])


if __name__ == "__main__":
    unittest.main()
