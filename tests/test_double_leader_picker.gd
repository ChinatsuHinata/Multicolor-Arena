extends "res://tests/test_v092.gd"

func choice_tile(uid: int) -> Control:
 if not is_instance_valid(view.modal_root):return null
 for node in view.modal_root.find_children("*","Control",true,false):
  if int(node.get_meta("leader_choice_uid",0))==uid:return node
 return null

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/test-double-leader-picker/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.load_legacy_test_decks()
 app.begin_battle(true)
 view=app.duel_view
 view.set_process(false)
 e=view.engine
 clean()
 var primary=e.make_card("new-eto-001",0,"leader",true)
 var extra=e.make_card("new-eto-002",0,"leader",true)
 e.players[0].leader=primary
 e.players[0].extra_leaders=[extra]
 put("164","field")
 put("167","field")
 put("164","palette")
 put("167","palette")
 put("167","palette")
 view.table.set_top_down_view(true)
 view.render()
 await settle()
 expect(e.cast_error(0,primary.uid).is_empty() and e.cast_error(0,extra.uid).is_empty(),"both leader cards can be cast")
 expect(view.table.visuals.has("card_"+str(primary.uid)) and not view.table.visuals.has("card_"+str(extra.uid)),"only the original leader is displayed in the leader zone")
 await click(point(primary.uid))
 expect(choice_tile(primary.uid)!=null and choice_tile(extra.uid)!=null,"clicking the leader zone offers both leaders")
 var tile=choice_tile(extra.uid)
 if tile:await click(tile.get_global_rect().get_center())
 expect(view.local.get("uid",0)==extra.uid,"choosing the double starts casting that leader")
 view.cancel_cast()
 await click(view.project(view.table.zone_position("leader",0)+Vector3(0,0,1.4)))
 expect(choice_tile(primary.uid)!=null and choice_tile(extra.uid)!=null,"clicking empty leader-zone space offers the same choice")
 tile=choice_tile(primary.uid)
 if tile:await click(tile.get_global_rect().get_center())
 expect(view.local.get("uid",0)==primary.uid,"choosing the original starts casting that leader")
 view.cancel_cast()
 extra.timer=1
 view.render()
 await click(point(primary.uid))
 tile=choice_tile(extra.uid)
 if tile:await click(tile.get_global_rect().get_center())
 expect(view.local.is_empty() and choice_tile(primary.uid)!=null,"a timed leader stays in the choice list but cannot be chosen")
 view.close_overlay()
 extra.timer=0
 e.move_to(primary,"field",false)
 view.render()
 await settle()
 expect(view.table.visuals.has("card_"+str(extra.uid)) and view.table.descriptors["card_"+str(extra.uid)].at==view.table.zone_position("leader",0),"the double appears in the leader zone after the original leaves")
 await click(point(extra.uid))
 expect(view.local.get("uid",0)==extra.uid,"clicking the displayed double starts casting it")
 view.cancel_cast()
 e.move_to(primary,"leader",false)
 view.render()
 await settle()
 expect(view.table.visuals.has("card_"+str(primary.uid)) and not view.table.visuals.has("card_"+str(extra.uid)),"the original replaces the double when it returns to the leader zone")
 print("DOUBLE LEADER PICKER: ",checks," checks; failures=",failures.size())
 app.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
