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
 var read_only=all_cards.filter(func(id):return not Store.CARDS[id].constructible or Store.CARDS[id].token)
 check(read_only.size()==23 and all_cards.has("character-ucs-020") and all_cards.has("character-ucs-021") and all_cards.has("token-ucs-099"),"library includes all dream and token cards")
 app.query="梦违"
 var dreams=app.library_ids()
 check(dreams.size()==7 and dreams.all(func(id):return not Store.CARDS[id].constructible and not Store.CARDS[id].token),"dream search finds seven read-only cards")
 app.query="衍生物"
 var tokens=app.library_ids()
 check(tokens.size()==16 and tokens.all(func(id):return Store.CARDS[id].token),"token search finds sixteen read-only cards")
 app.update_library()
 check(app.library.get_children().all(func(row):return not row.draggable),"read-only search rows cannot be dragged")
 var before=JSON.stringify([app.draft.main,app.draft.side,app.draft.leader])
 var token_row=app.library.get_children()[0]
 token_row.clicked.emit(token_row.card_id,"library",-1,false)
 check(app.selected==token_row.card_id and JSON.stringify([app.draft.main,app.draft.side,app.draft.leader])==before,"clicking token previews without adding it")
 check(not app.valid_drag_source({"card_id":"token-ucs-099","source_zone":"library"}),"token drag is rejected")
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
