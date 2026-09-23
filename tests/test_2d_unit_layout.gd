extends "res://tests/test_v092.gd"

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/test-2d-unit-layout/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.load_legacy_test_decks()
 app.begin_battle(true)
 view=app.duel_view
 view.set_process(false)
 e=view.engine
 clean()
 view.table.set_top_down_view(true)
 for i in range(5):put("53","field")
 var played=put("53","hand")
 put("164","palette")
 var error=e.commit_cast(0,played.uid,{},e.payment(0,e.cast_cost(0,played)).plan)
 expect(error.is_empty(),"unit can be cast in 2D view")
 if error.is_empty():resolve()
 e.presentation_events.clear()
 view.render()
 await settle()
 expect(played.zone=="field" and e.players[0].field.size()==6,"cast unit resolves onto the battlefield")
 var units=view.table.descriptors.values().filter(func(d):return d.zone=="field" and d.group=="unit" and d.owner==0)
 expect(units.size()==6,"all six unit cards have battlefield positions")
 if units.size()==6:
  units.sort_custom(func(a,b):return a.at.x<b.at.x)
  var half_card=view.table.CARD_SIZE.x*view.table.FIELD_SCALE/2.0
  expect(units.all(func(d):return absf(d.at.x)+half_card<5.4),"2D unit cards remain inside the printed battlefield")
  var separated=true
  for i in range(1,units.size()):
   if units[i].at.x-units[i-1].at.x<half_card*2.0:separated=false
  expect(separated,"six 2D unit cards do not overlap")
  expect(view.table.visuals["card_"+str(played.uid)].position.distance_to(view.table.descriptors["card_"+str(played.uid)].at)<0.05,"resolved card reaches its assigned position")
  expect(is_equal_approx(view.table.field_position("unit",0,6,1).x,-units[0].at.x),"opponent unit row mirrors the local row")
 for i in range(4):put("164","field")
 for i in range(2):put("169","field")
 view.render()
 await settle()
 var items=view.table.descriptors.values().filter(func(d):return d.zone=="field" and d.group=="item" and d.owner==0)
 var supports=view.table.descriptors.values().filter(func(d):return d.zone=="field" and d.group=="support" and d.owner==0)
 expect(items.size()==4 and supports.size()==2,"2D item and barrier cards are placed")
 var item_half=view.table.CARD_SIZE*view.table.FIELD_SCALE*0.5
 expect(items.all(func(d):return d.at.x-item_half.x>-5.4 and d.at.x+item_half.x<5.4 and d.at.z+item_half.y<4.1),"2D items fit the printed battlefield")
 expect(supports.all(func(d):return d.at.x-view.table.CARD_SIZE.y*view.table.FIELD_SCALE*0.5>-5.4 and d.at.x+view.table.CARD_SIZE.y*view.table.FIELD_SCALE*0.5<5.4 and d.at.z+item_half.x<4.1),"2D barriers fit the printed battlefield")
 expect(items.all(func(d):return d.at.z-item_half.y>view.table.field_position("unit",0,6,0).z+item_half.y),"2D back row does not overlap the unit row")
 expect(items.all(func(d):return d.at.z+item_half.y<view.table.zone_position("palette",0).z-item_half.y),"2D items do not cover the palette")
 expect(is_equal_approx(view.table.field_position("item",0,4,1).x,-items[0].at.x) and is_equal_approx(view.table.field_position("support",0,2,1).z,-supports[0].at.z),"opponent item and barrier rows mirror local rows")
 view.table.set_top_down_view(false)
 expect(is_equal_approx(view.table.field_position("unit",0,6,0).x,-6.4),"3D unit row keeps its original coordinates")
 expect(is_equal_approx(view.table.field_position("item",0,4,0).x,-6.35) and is_equal_approx(view.table.field_position("support",0,2,0).z,4.3),"3D item and barrier rows keep their original coordinates")
 print("2D UNIT LAYOUT: ",checks," checks; failures=",failures.size())
 app.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
