"""Server-priced, account-owned cosmetics. All purchases debit the task wallet."""
import json
import time
from pathlib import Path

_catalogue_path = Path(__file__).resolve().parent / "data/shop.json"
if not _catalogue_path.is_file():
    _catalogue_path = Path(__file__).resolve().parents[1] / "data/shop.json"
CATALOGUE = json.loads(_catalogue_path.read_text(encoding="utf-8"))
PRODUCTS = {p["id"]: int(p["price"]) for p in CATALOGUE["products"] if not p.get("test_only")}
SALE = CATALOGUE.get("sale", {})


def discounted_price(price):
    """Every sale uses half the base price, rounded up to whole copper."""
    return (price + 1) // 2


def price_for(product_id, now=None):
    now = time.time() if now is None else now
    special = SALE.get("all_products") or any(
        p["id"] == product_id and p.get("special") for p in CATALOGUE["products"])
    price = PRODUCTS[product_id]
    return discounted_price(price) if special and SALE.get("starts_at", 0) <= now < SALE.get("ends_at", 0) else price


def initialize(conn):
    conn.execute("""CREATE TABLE IF NOT EXISTS shop_purchases (
        player_id INTEGER NOT NULL, product_id TEXT NOT NULL, price INTEGER NOT NULL,
        purchased_at INTEGER NOT NULL, PRIMARY KEY(player_id,product_id),
        FOREIGN KEY(player_id) REFERENCES players(id))""")


def owned(conn, player_id):
    return [row[0] for row in conn.execute(
        "SELECT product_id FROM shop_purchases WHERE player_id=? ORDER BY product_id", (player_id,))]


def purchase(conn, player_id, product_id, expected_price=None):
    if not isinstance(product_id, str) or product_id not in PRODUCTS:
        raise ValueError("商品不存在或已下架")
    with conn:
        # Lock before inspecting ownership: retries and concurrent devices debit once.
        conn.execute("INSERT OR IGNORE INTO task_wallets(player_id,coins) VALUES(?,0)", (player_id,))
        if product_id in owned(conn, player_id):
            return "已拥有此商品，无需重复购买"
        now = int(time.time())
        price = price_for(product_id, now)
        if expected_price is not None and (type(expected_price) not in (int, float) or expected_price != price):
            raise ValueError("商品价格已更新，请重新确认购买")
        debit = conn.execute("UPDATE task_wallets SET coins=coins-? WHERE player_id=? AND coins>=?",
                             (price, player_id, price))
        if debit.rowcount != 1:
            raise ValueError(f"铜钱不足，需要 {price} 铜钱")
        conn.execute("INSERT INTO shop_purchases(player_id,product_id,price,purchased_at) VALUES(?,?,?,?)",
                     (player_id, product_id, price, now))
    return "购买成功，可在我的商品中管理对战开关"
