extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
var failures=[]

func check(ok: bool,description: String):
 if ok:print("PASS "+description)
 else:failures.append(description);push_error(description)

func press_key(view,key: int):
 var event=InputEventKey.new()
 event.keycode=key
 event.pressed=true
 view._unhandled_key_input(event)

func _initialize():call_deferred("run")

func run():
 var app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.draft=Store.blank("卡库检查")
 app.draft.leader="70"
 app.editor()
 await process_frame
 var all_cards=app.library_ids()
 check(all_cards.all(func(id):return Store.CARDS[id].constructible and not Store.CARDS[id].token) and not all_cards.has("character-ucs-020") and not all_cards.has("character-ucs-021"),"library hides dream and token cards")
 for term in ["梦违","衍生物"]:
  app.query=term
  check(app.library_ids().all(func(id):return Store.CARDS[id].constructible and not Store.CARDS[id].token),"search keeps excluded cards hidden: "+term)
 app.query="蓝康"
 check(app.library_ids().has("spell-fdn-069"),"blue counter alias finds 青ノ花")
 app.query="绿康"
 check(app.library_ids().has("spell-fdn-066"),"green counter alias finds 妖精ノ巡礼")
 app.query="妖精"
 var fairies=app.library_ids()
 check(fairies.has("57") and fairies.has("spell-fdn-066") and fairies.has("item-lof-009"),"fairy race search combines units, spells and items")
 app.query="神"
 check(app.library_ids().has("field-fdf-107"),"race search includes fields")
 app.begin_battle(true)
 await process_frame
 var view=app.duel_view
 for i in range(12):
  if not view.revealing():break
  await create_timer(0.5).timeout
 view.render()
 await process_frame
 check(view.hud.get_children().any(func(child):return child is Label and child.text=="G  墓地" and child.position.y>=860) and view.hud.get_children().any(func(child):return child is Label and child.text=="H  除外区" and child.position.y>=860),"G and H hints appear at bottom left")
 press_key(view,KEY_G)
 check(view.debug_open and view.browser_zone=="grave","G opens graveyard")
 press_key(view,KEY_G)
 check(not view.debug_open,"G closes graveyard")
 press_key(view,KEY_H)
 check(view.debug_open and view.browser_zone=="exile","H opens exile")
 press_key(view,KEY_H)
 check(not view.debug_open,"H closes exile")
 print("CATALOG_SHORTCUTS ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
