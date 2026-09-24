extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Rules=preload("res://scripts/deck_rule_set.gd")
var failures=[]

func check(ok: bool,description: String):
 if ok:print("PASS "+description)
 else:failures.append(description);push_error(description)

func _initialize():call_deferred("run")

func run():
 var app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.draft=Store.blank("规则界面测试")
 app.draft.leader="70"
 app.query="莱瓦汀"
 app.editor()
 await process_frame
 var choice=app.screen.get_node_or_null("DeckRuleSet") as OptionButton
 check(choice!=null and choice.item_count==Rules.IDS.size(),"deck editor offers four rule sets")
 check("主卡组 0 / 50" in app.counts.text,"ordinary rules show 50-card main limit")
 choice.select(1);choice.item_selected.emit(1)
 check(app.draft.rule_set==Rules.OFFICIAL,"deck editor records selected rule")
 var remaining_text=""
 for row in app.library.get_children():
  if row.get_meta("card_id","")!="104":continue
  for child in row.get_children():
   if child is Label and child.text.begins_with("余 "):remaining_text=child.text
 check(remaining_text=="余 2","library shows official remaining copies")
 app.selected="104"
 app.add_to("main")
 check(Rules.remaining(app.draft,"104",Store.CARDS,Rules.OFFICIAL)==1,"library count updates after adding")
 choice.select(3);choice.item_selected.emit(3)
 check("主卡组 1 / 70" in app.counts.text,"test rule shows 70-card main limit")
 var has_remaining=false
 for row in app.library.get_children():
  if row.get_meta("card_id","")!="104":continue
  for child in row.get_children():
   if child is Label and child.text.begins_with("余 "):has_remaining=true
 check(not has_remaining,"unlimited test rule hides remaining count")
 app.online()
 await process_frame
 var room_choice=app.screen.find_child("RoomRuleSet",true,false) as OptionButton
 check(room_choice!=null and room_choice.item_count==Rules.IDS.size(),"host room offers four rule sets")
 room_choice.select(1)
 var host_error=app.lan_session.create_room(1,false,47993,"127.0.0.1",Rules.IDS[room_choice.selected])
 check(host_error.is_empty() and app.lan_session.room.get("rule_set","")==Rules.OFFICIAL,"created room publishes selected official rule")
 if is_instance_valid(app.lan_session):app.lan_session.leave(false)
 print("RULE_SET_UI ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
