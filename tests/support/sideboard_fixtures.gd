extends RefCounted
const Store=preload("res://scripts/deck_store.gd")

static func deck(leader: String,title: String="赛前备牌测试") -> Dictionary:
 var result=Store.blank(title);result.leader=leader;result.rule_set="test"
 for i in range(50):result.main.append("53")
 for i in range(10):result.side.append("100")
 return Store.clean_deck(result)

static func swapped(original: Dictionary,count: int) -> Dictionary:
 var result=original.duplicate(true)
 for i in range(count):
  var id=result.main[i];result.main[i]=result.side[i];result.side[i]=id
 return result
