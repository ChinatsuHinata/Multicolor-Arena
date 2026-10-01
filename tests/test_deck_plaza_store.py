"""Cloud text boundary, authenticated authorship, pagination and persistence."""
import base64
import json
import sys
import tempfile
import time
import unittest
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store as accounts
import deck_plaza_store as plaza


class DeckPlazaTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = Path(self.directory.name) / "players.sqlite3"
        self.conn = accounts.database(self.path)
        accounts.handle(self.conn, {"action": "register", "username": "plaza_player", "password": "password123!", "device": "a" * 32})
        self.login = accounts.handle(self.conn, {"action": "login", "username": "plaza_player", "password": "password123!", "device": "a" * 32})
        self.account = accounts.verify(self.conn, self.login["token"])
        self.parts = ["原卡组", "70", [["100", 4]], [], "official_spx", {"70": "tts_151600"}]
        self.payload = {"action": "upload", "token": self.login["token"], "title": "灵梦套牌", "description": "第一行\n第二行", "tags": ["灵梦", "速攻"], "deck_code": "MA1:" + json.dumps(self.parts, ensure_ascii=False)}

    def tearDown(self):
        self.conn.close()
        self.directory.cleanup()

    def request(self, data):
        account = accounts.verify(self.conn, data.get("token"))
        return plaza.handle(self.conn, data, account) if account["ok"] else account

    def test_upload_persists_author_and_alternate_art(self):
        result = self.request(self.payload)
        self.assertTrue(result["ok"])
        self.conn.close()
        self.conn = accounts.database(self.path)
        detail = self.request({"action": "detail", "token": self.login["token"], "id": result["id"]})["deck"]
        self.assertEqual(detail["title"], "灵梦套牌")
        self.assertEqual(detail["description"], "第一行\n第二行")
        self.assertEqual(detail["username"], "plaza_player")
        self.assertEqual(detail["tags"], ["灵梦", "速攻"])
        self.assertEqual(plaza.deck_parts(detail["deck_code"])[5], {"70": "tts_151600"})
        self.assertEqual(plaza.deck_parts(detail["deck_code"])[0], detail["title"])

    def test_compressed_code_and_assets_rejected(self):
        raw = json.dumps(self.parts, ensure_ascii=False).encode("utf-8")
        code = "MA1Z:" + str(len(raw)) + ":" + base64.b64encode(zlib.compress(raw)).decode().rstrip("=")
        self.assertTrue(self.request(dict(self.payload, deck_code=code))["ok"])
        for extra in ({"image": "data:image/png;base64,AAAA"}, {"username": "forged_author"}, {"assets": []}):
            self.assertFalse(self.request(dict(self.payload, **extra))["ok"])
        for arts in ({"70": "res://image.png"}, {"70": "https://image.example/pic.png"}, {"70": {"image": "AAAA"}}):
            parts = self.parts[:5] + [arts]
            self.assertFalse(self.request(dict(self.payload, deck_code="MA1:" + json.dumps(parts)))["ok"])
        self.assertFalse(self.request(dict(self.payload, deck_code=json.dumps({"leader": "70", "image": "AAAA"})))["ok"])
        parts = self.parts + [{"assets": "AAAA"}]
        self.assertFalse(self.request(dict(self.payload, deck_code="MA1:" + json.dumps(parts)))["ok"])

    def test_limits_and_malformed_requests(self):
        self.assertTrue(self.request(dict(self.payload, tags=[str(i) for i in range(10)]))["ok"])
        for change in ({"tags": [str(i) for i in range(11)]}, {"title": " "}, {"title": "字" * 41}, {"description": "字" * 2001}, {"tags": ["a,b"]}, {"action": []}, {"deck_code": "MA1Z:999999:AAAA"}):
            self.assertFalse(self.request(dict(self.payload, **change))["ok"])

    def test_every_operation_requires_live_login(self):
        for data in (self.payload, {"action": "list"}, {"action": "detail", "id": 1}):
            self.assertFalse(self.request(dict(data, token=""))["ok"])
        self.conn.execute("UPDATE sessions SET issued_at=?", (int(time.time()) - accounts.SESSION_LIFETIME - 1,))
        self.assertFalse(self.request(dict(self.payload))["ok"])

    def test_pagination_and_private_session_fields(self):
        ids = [self.request(dict(self.payload, title=f"套牌{i}"))["id"] for i in range(8)]
        first = self.request({"action": "list", "token": self.login["token"], "page": 0})
        second = self.request({"action": "list", "token": self.login["token"], "page": 1})
        self.assertEqual([p["id"] for p in first["decks"]], list(reversed(ids[2:])))
        self.assertEqual([p["id"] for p in second["decks"]], list(reversed(ids[:2])))
        self.assertEqual(first["pages"], 2)
        self.assertEqual(first["total"], 8)
        for post in first["decks"]:
            self.assertNotIn("description", post)
            self.assertNotIn("token", post)
            self.assertNotIn("device", post)
            self.assertNotIn("player_id", post)
        self.assertFalse(self.request({"action": "detail", "token": self.login["token"], "id": -1})["ok"])

    def test_colors_exclude_lily_stone_and_every_rainbow_card(self):
        excluded = [card_id for card_id, info in plaza.catalogue().items() if info["exclude_colors"] and info["constructible"]]
        parts = ["极彩排除测试", "70", excluded, [], "test"]
        _, colors = plaza.deck_metadata(parts)
        self.assertEqual(colors, "红黄")
        parts[3] = ["103"]  # Sideboard contributes green.
        _, colors = plaza.deck_metadata(parts)
        self.assertEqual(colors, "红绿黄")
        self.assertIn("128", excluded)
        self.assertIn("character-soi-006", excluded)
        self.assertIn("spell-htk-004", excluded)

    def test_search_all_pages_leader_aliases_colors_and_tags(self):
        self.request(dict(self.payload, tags=["早期套牌"] ))
        for i in range(7):
            self.request(dict(self.payload, tags=[f"其他{i}"]))
        query = {"action": "list", "token": self.login["token"], "leader": "灵梦", "tag": "早期", "color_text": "红黄", "colors": ["红"]}
        result = self.request(query)
        self.assertEqual(result["total"], 1)
        self.assertEqual(result["decks"][0]["colors"], ["红", "黄"])
        self.assertEqual(self.request(dict(query, colors=["黑"]))["total"], 0)
        self.assertFalse(self.request(dict(query, color_text="单红"))["ok"])
        self.assertEqual(self.request(dict(query, tag="%"))["total"], 0)
        self.assertFalse(self.request(dict(query, color_text="单红蓝"))["ok"])
        self.assertEqual(plaza.color_query(" 红 "), ["红"])
        self.assertEqual(plaza.color_query("红蓝"), ["红", "蓝"])

    def test_comma_tags_require_every_term_before_pagination(self):
        both = self.request(self.payload)["id"]
        for tags in (["灵梦"], ["速攻"], ["其他"], ["灵梦", "其他"], ["速攻", "其他"], ["其他"]):
            self.request(dict(self.payload, tags=tags))
        query = {"action": "list", "token": self.login["token"], "tag": "灵梦，速攻"}
        for term in ("灵梦，速攻", "速攻,灵梦", " ， 灵梦, 速攻 ，灵梦, "):
            result = self.request(dict(query, tag=term))
            self.assertTrue(result["ok"])
            self.assertEqual(result["total"], 1)
            self.assertEqual([post["id"] for post in result["decks"]], [both])
            self.assertEqual(result["pages"], 1)
        self.assertEqual(self.request(dict(query, tag="灵梦,不存在"))["total"], 0)
        self.assertEqual(self.request(dict(query, tag="灵梦,%"))["total"], 0)
        self.assertEqual(self.request(dict(query, tag="灵梦,_"))["total"], 0)
        self.assertEqual(self.request(dict(query, tag=" ，, "))["total"], 7)
        self.assertFalse(self.request(dict(query, tag="字" * 61))["ok"])

    def test_removed_single_color_commands_and_color_inclusion(self):
        self.request(self.payload)
        query = {"action": "list", "token": self.login["token"]}
        for color in plaza.COLORS:
            self.assertFalse(self.request(dict(query, color_text="单" + color))["ok"])
        self.assertEqual(self.request(dict(query, color_text="红"))["total"], 1)
        self.assertEqual(self.request(dict(query, color_text=" 红 黄色 "))["total"], 1)
        self.assertEqual(self.request(dict(query, color_text="红蓝"))["total"], 0)

    def test_owner_edit_delete_and_mine_list(self):
        post_id = self.request(self.payload)["id"]
        self.assertTrue(self.request({"action": "detail", "id": post_id, "token": self.login["token"]})["deck"]["owned"])
        accounts.handle(self.conn, {"action": "register", "username": "other_player", "password": "password123!", "device": "b" * 32})
        other = accounts.handle(self.conn, {"action": "login", "username": "other_player", "password": "password123!", "device": "b" * 32})
        update = dict(self.payload, action="edit", id=post_id, title="修改后的标题", tags=["新标签"])
        self.assertFalse(self.request(dict(update, token=other["token"]))["ok"])
        self.assertFalse(self.request({"action": "delete", "id": post_id, "token": other["token"]})["ok"])
        self.assertEqual(self.request({"action": "list", "token": other["token"], "mine": True})["total"], 0)
        self.assertFalse(self.request({"action": "detail", "id": post_id, "token": other["token"]})["deck"]["owned"])
        parts = self.parts.copy()
        parts[2] = ["103"]
        changed = self.request(dict(update, deck_code="MA1:" + json.dumps(parts, ensure_ascii=False)))
        self.assertTrue(changed["ok"])
        self.assertEqual(changed["id"], post_id)
        self.assertEqual(changed["deck"]["colors"], ["红", "绿", "黄"])
        self.assertEqual(changed["deck"]["tags"], ["新标签"])
        mine = self.request({"action": "list", "token": self.login["token"], "mine": True})
        self.assertEqual(mine["total"], 1)
        self.assertTrue(self.request({"action": "delete", "id": post_id, "token": self.login["token"]})["ok"])
        self.assertFalse(self.request({"action": "detail", "id": post_id, "token": self.login["token"]})["ok"])
        self.assertEqual(self.request({"action": "list", "token": self.login["token"], "mine": True})["total"], 0)

    def test_existing_posts_migrate_and_recompute_colors(self):
        post_id = self.request(self.payload)["id"]
        self.conn.execute("UPDATE deck_posts SET colors='红蓝绿黄黑',leader_search='' WHERE id=?", (post_id,))
        self.conn.commit()
        self.conn.close()
        self.conn = accounts.database(self.path)
        detail = self.request({"action": "detail", "id": post_id, "token": self.login["token"]})["deck"]
        self.assertEqual(detail["colors"], ["红", "黄"])
        self.assertEqual(self.request({"action": "list", "token": self.login["token"], "leader": "灵梦"})["total"], 1)


if __name__ == "__main__":
    unittest.main()
