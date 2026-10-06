extends RefCounted
const Store=preload("res://scripts/deck_store.gd")
const Model=preload("res://scripts/tutorial/authoring_model.gd")

static func scene() -> Dictionary:
 var value=Model.battle();value.players[0].hand=[{"card_id":"129","alias":"maker"}]
 for color in ["红","红","红","蓝","绿","黄","黑","黑"]:
  for id in Store.CARDS:
   if Store.CARDS[id].get("colors",[])==[color] and not id.begins_with("roster_token"):
    value.players[0].palette.append({"card_id":id})
    break
 return value

static func cast(adapter) -> String:
 var e=adapter.engine;var card=adapter.entity("maker");var target={"none":true}
 var reason=e.commit_cast(0,int(card.uid),target,e.payment(0,e.cast_cost(0,card,target)).plan)
 if not reason.is_empty():return reason
 e.pass_priority(1);e.pass_priority(0)
 return "" if e.units(0).filter(func(c):return c.get("token",false)).size()==2 else "spell did not create both tokens"
