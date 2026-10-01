extends "res://tests/support/rules_base.gd"

func run():
 for mode in ["destroy", "sacrifice"]:
  fresh()
  put("22")
  var victim=put("53")
  e.players[0].life=10
  if mode=="destroy": e.destroy(victim)
  else: e.sacrifice(victim)
  expect(e.triggers.filter(func(t): return t.get("effect","")=="mystia_life").size()==1,"夜雀在己方单位%s时触发一次" % ("死亡" if mode=="destroy" else "牺牲"))
  settle()
  expect(e.players[0].life==11,"己方单位%s后夜雀回复一点生命" % ("死亡" if mode=="destroy" else "牺牲"))
 for card_id in ["164", "170"]:
  fresh()
  put("22")
  var permanent=put(card_id)
  e.players[0].life=10
  e.sacrifice(permanent)
  expect(not e.triggers.any(func(t): return t.get("effect","")=="mystia_life"),"牺牲%s不会触发夜雀" % e.cards[card_id].kind)
  settle()
  expect(e.players[0].life==10,"牺牲%s后生命不变" % e.cards[card_id].kind)
 fresh()
 put("22")
 e.players[0].life=10
 e.sacrifice(put("53","field",1))
 expect(not e.triggers.any(func(t): return t.get("effect","")=="mystia_life"),"对手单位死亡不触发夜雀")
 settle()
 expect(e.players[0].life==10,"对手单位死亡后生命不变")
 print("MYSTIA_LIFE: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
