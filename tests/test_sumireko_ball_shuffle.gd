extends SceneTree

const E = preload("res://scripts/rules/duel_engine.gd")
const N = E.Roster.New

var failures: Array[String] = []

func _init() -> void:
 call_deferred("run")

func check(ok: bool, title: String) -> void:
 if ok:
  print("PASS " + title)
 else:
  failures.append(title)
  push_error(title)

func fresh_game():
 var e = E.new()
 var deck = {"leader": N.id("ETO-001"), "main": []}
 for i in range(50):
  deck.main.append("53")
 e.start(deck, deck, 0, 42)
 for p in e.players:
  for zone in ["hand", "field", "palette", "grave", "exile"]:
   p[zone] = []
  p.mulligan_done = true
 e.phase = "main"
 e.pending = {}
 e.triggers = []
 e.players[0].deck = []
 for card_id in ["53", "54", "56", "57", "68"]:
  e.players[0].deck.append(e.make_card(card_id, 0, "deck"))
 return e

func choose_ball_count(e, count: int) -> void:
 N.on_cast(e, e.players[0].leader, 0, "leader")
 var trigger = e.triggers.pop_back()
 trigger.target = {"none": true}
 N.resolve_trigger(e, trigger)
 e.choose_effect({"none": true, "x": count, "mode": "洗入%d张灵异珠" % count})

func run() -> void:
 var e = fresh_game()
 var original_order = e.players[0].deck.map(func(c): return c.uid)
 var original_rng_state = e.rng.state
 choose_ball_count(e, 0)
 check(e.players[0].deck.map(func(c): return c.uid) == original_order, "选择0张灵异珠时牌库顺序保持不变")
 check(e.rng.state == original_rng_state, "选择0张灵异珠时不消耗洗牌随机数")
 check(e.players[0].hand.filter(func(c): return c.card_id == N.id("ETO-S001")).size() == 2, "选择0张仍将两张灵异珠置于手牌")

 e = fresh_game()
 original_rng_state = e.rng.state
 choose_ball_count(e, 3)
 check(e.players[0].deck.filter(func(c): return c.card_id == N.id("ETO-S001")).size() == 3, "选择3张将灵异珠加入牌库")
 check(e.rng.state != original_rng_state, "选择3张仍会洗牌")

 if failures.is_empty():
  print("PASS sumireko ball shuffle")
  quit(0)
 else:
  print("FAIL ", failures)
  quit(1)
