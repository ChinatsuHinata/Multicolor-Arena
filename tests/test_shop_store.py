"""Paid cosmetics: authenticated purchases, atomic wallet debits and delisting."""
import hashlib
import json
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "relay"))
import account_store as accounts
import shop_store as shop


class ShopTests(unittest.TestCase):
    def setUp(self):
        self.clock = patch.object(shop.time, "time", return_value=shop.SALE["starts_at"] + 3600)
        self.clock.start()
        self.addCleanup(self.clock.stop)
        scratch = ROOT / "work/shop-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="TEST_ONLY_shop_", dir=scratch)
        self.path = Path(self.temp.name) / "players.sqlite3"
        self.conn = accounts.database(self.path)
        self.token = "a" * 64
        with self.conn:
            for player in (1, 2):
                self.conn.execute("INSERT INTO players(id,username,password_salt,password_hash,created_at) VALUES(?,?,?,?,0)",
                                  (player, f"TEST_ONLY_{player}", b"salt", b"hash"))
            self.conn.execute("INSERT INTO sessions(player_id,platform,token_hash,device,issued_at) VALUES(1,'pc',?,?,?)",
                              (hashlib.sha256(self.token.encode()).digest(), "d" * 32, int(time.time())))
            self.conn.execute("INSERT INTO task_wallets(player_id,coins) VALUES(1,50)")

    def tearDown(self):
        self.conn.close()
        self.temp.cleanup()

    def buy(self, product="emotes_reimu", **extra):
        return accounts.handle(self.conn, {"action": "shop_buy", "token": self.token, "product_id": product, **extra})

    def test_purchase_retry_and_restart(self):
        for _ in range(2):
            result = self.buy(price=0, player_id=2)
            self.assertTrue(result["ok"])
            self.assertEqual(result["tasks"]["coins"], 45)
            self.assertEqual(result["tasks"]["purchased_product_ids"], ["emotes_reimu"])
            self.assertEqual(result["tasks"]["shop_grants"], {"emotes_reimu": ""})
        self.assertEqual(shop.owned(self.conn, 2), [])
        self.conn.close();self.conn = accounts.database(self.path)
        self.assertEqual(shop.owned(self.conn, 1), ["emotes_reimu"])

    def test_insufficient_unknown_delisted_and_auth(self):
        with self.conn:self.conn.execute("UPDATE task_wallets SET coins=4")
        for product in ("emotes_reimu", "test_leader_emotes", "unknown", None, []):
            self.assertFalse(self.buy(product)["ok"])
        self.assertFalse(self.buy(token="invalid")["ok"])
        self.assertEqual(shop.owned(self.conn, 1), [])
        self.assertEqual(self.conn.execute("SELECT coins FROM task_wallets WHERE player_id=1").fetchone()[0], 4)

    def test_concurrent_purchase(self):
        def buy(_):
            conn = accounts.database(self.path)
            try:return accounts.handle(conn, {"action":"shop_buy", "token":self.token, "product_id":"emotes_reimu"})
            finally:conn.close()
        with ThreadPoolExecutor(max_workers=2) as pool:
            self.assertTrue(all(r["ok"] for r in pool.map(buy, range(2))))
        self.assertEqual(self.conn.execute("SELECT coins FROM task_wallets WHERE player_id=1").fetchone()[0], 45)

    def test_catalogue_and_all_products(self):
        products = json.loads((ROOT / "data/shop.json").read_text(encoding="utf-8"))["products"]
        self.assertEqual({p["id"]: p["price"] for p in products}, shop.PRODUCTS)
        budget = sum(shop.price_for(product["id"]) for product in products) + 17
        with self.conn:self.conn.execute("UPDATE task_wallets SET coins=? WHERE player_id=1", (budget,))
        for product in products:self.assertTrue(self.buy(product["id"])["ok"])
        self.assertEqual(self.conn.execute("SELECT coins FROM task_wallets WHERE player_id=1").fetchone()[0], 17)
        self.assertEqual(set(shop.owned(self.conn, 1)), {p["id"] for p in products})

    def test_half_price_rounding_and_deadline(self):
        self.assertEqual([shop.discounted_price(p) for p in (0, 1, 9, 10, 11)], [0, 1, 5, 5, 6])
        for product in shop.PRODUCTS:
            for now, price in ((shop.SALE["starts_at"] - 1, 10), (shop.SALE["starts_at"], 5),
                               (shop.SALE["ends_at"] - 1, 5), (shop.SALE["ends_at"], 10)):
                self.assertEqual(shop.price_for(product, now), price)

    def test_expired_quote_never_debits_more_than_confirmed(self):
        with patch.object(shop.time, "time", return_value=shop.SALE["ends_at"]):
            with self.conn:self.conn.execute("UPDATE sessions SET issued_at=?", (int(time.time()),))
            result = self.buy(expected_price=5)
            self.assertFalse(result["ok"])
            self.assertIn("重新确认", result["message"])
            self.assertEqual(result["tasks"]["coins"], 50)
            self.assertEqual(shop.owned(self.conn, 1), [])
            self.assertTrue(self.buy(expected_price=10)["ok"])
        self.assertEqual(self.conn.execute("SELECT coins FROM task_wallets WHERE player_id=1").fetchone()[0], 40)
        self.assertEqual(self.conn.execute("SELECT price FROM shop_purchases").fetchone()[0], 10)

    def test_sale_quote_and_recorded_debit(self):
        self.assertFalse(self.buy(expected_price=0)["ok"])
        self.assertFalse(self.buy(expected_price=True)["ok"])
        self.assertTrue(self.buy(expected_price=5.0)["ok"])
        self.assertEqual(self.conn.execute("SELECT price FROM shop_purchases").fetchone()[0], 5)


if __name__ == "__main__":unittest.main()
