extends "res://tests/test_v092.gd"

func fits_zone(group: String,at: Vector3,who: int,half: Vector2) -> bool:
 var footprint=Rect2(Vector2(at.x,at.z)-half,half*2.0)
 return view.table.wide_zone_bounds(group,who).encloses(footprint)

func clear_of_fixed_slots(at: Vector3,half: Vector2) -> bool:
 var footprint=Rect2(Vector2(at.x,at.z)-half,half*2.0)
 var fixed_half=view.table.CARD_SIZE*view.table.SLOT_SCALE*0.5
 for who in range(2):
  for zone in ["leader","deck","grave","exile"]:
   var center=view.table.zone_position(zone,who)
   var slot=Rect2(Vector2(center.x,center.z)-fixed_half,fixed_half*2.0)
   if footprint.intersects(slot):return false
 return true

func clear_of_melody(at: Vector3,half: Vector2) -> bool:
 var footprint=Rect2(Vector2(at.x,at.z)-half,half*2.0)
 for who in range(2):
  if footprint.intersects(view.table.wide_zone_bounds("melody",who)):return false
 return true

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
  var large_half=Vector2.ONE*view.table.CARD_SIZE.y*view.table.FIELD_SCALE*0.5
  expect(units.all(func(d):return fits_zone("unit",d.at,0,large_half)),"2D units fit entirely in the upper zone, including when tapped")
  expect(units[-1].at.x-units[0].at.x>14.0,"six units use the extended battlefield width")
  var separated=true
  for i in range(1,units.size()):
   if units[i].at.x-units[i-1].at.x<half_card*2.0:separated=false
  expect(separated,"six 2D unit cards do not overlap")
  expect(view.table.visuals["card_"+str(played.uid)].position.distance_to(view.table.descriptors["card_"+str(played.uid)].at)<0.05,"resolved card reaches its assigned position")
  expect(is_equal_approx(view.table.field_position("unit",0,6,1).x,-units[0].at.x),"opponent unit row mirrors the local row")
  var opponent=view.table.field_position("unit",0,6,1)
  expect(units[0].at.z-opponent.z>view.table.CARD_SIZE.y*view.table.FIELD_SCALE+0.8,"opposing unit rows have a visible gap")
 for i in range(4):put("164","field")
 for i in range(2):put("169","field")
 view.render()
 await settle()
 var items=view.table.descriptors.values().filter(func(d):return d.zone=="field" and d.group=="item" and d.owner==0)
 var supports=view.table.descriptors.values().filter(func(d):return d.zone=="field" and d.group=="support" and d.owner==0)
 expect(items.size()==4 and supports.size()==2,"2D item and barrier cards are placed")
 var item_half=view.table.CARD_SIZE*view.table.FIELD_SCALE*0.5
 var large_half=Vector2.ONE*item_half.y
 expect(items.all(func(d):return fits_zone("item",d.at,0,large_half)),"2D items stay in the lower-left zone, including when tapped")
 expect(supports.all(func(d):return fits_zone("support",d.at,0,large_half)),"2D barriers stay in the lower-right zone")
 expect(items.all(func(d):return d.at.z-item_half.y>view.table.field_position("unit",0,6,0).z+item_half.y),"2D back row does not overlap the unit row")
 expect(items.all(func(d):return d.at.z+item_half.y<view.table.zone_position("palette",0).z-item_half.y),"2D items do not cover the palette")
 expect((units+items+supports).all(func(d):return clear_of_fixed_slots(d.at,large_half) and clear_of_melody(d.at,large_half)),"field cards leave the outer slots and melody areas clear")
 expect(is_equal_approx(view.table.field_position("item",0,4,1).x,-items[0].at.x) and is_equal_approx(view.table.support_placement(0,2,1).at.z,-supports[0].at.z),"opponent item and barrier rows mirror local rows")
 for i in range(7):put("164","palette")
 e.players[0].potato=true
 var melody_card=put("spell-fdf-042","field")
 view.render()
 await settle()
 var palette_cards=view.table.descriptors.values().filter(func(d):return d.zone=="palette" and d.owner==0 and d.uid>0)
 expect(palette_cards.size()==8 and palette_cards.all(func(d):return fits_zone("palette",d.at,0,large_half) and clear_of_fixed_slots(d.at,large_half) and clear_of_melody(d.at,large_half)),"eight color cards, even tapped, stay clear of the side slots")
 var potato=view.table.descriptors.get("card_-100",{})
 var potato_half=view.table.CARD_SIZE*0.52*0.5
 expect(not potato.is_empty() and fits_zone("palette",potato.at,0,potato_half) and clear_of_fixed_slots(potato.at,potato_half),"potato stays inside the palette instead of covering exile")
 expect(palette_cards.all(func(d):return d.at.x-large_half.x>potato.at.x+potato_half.x),"color cards leave a separate space for potato")
 var melody=view.table.descriptors.get("card_"+str(melody_card.uid),{})
 expect(not melody.is_empty() and melody.group=="melody" and fits_zone("melody",melody.at,0,large_half) and clear_of_fixed_slots(melody.at,large_half),"melody keeps its own side area")
 expect(fits_zone("melody",view.table.field_position("melody",0,1,1),1,large_half),"opposing melody area mirrors without overlap")
 for group in ["unit","item","support","palette","melody"]:
  var center=view.table.wide_zone_bounds(group,0).get_center()
  var hit=view.table.debug_drop_zone(view.table.camera.unproject_position(Vector3(center.x,0,center.y)),0)
  expect(hit==("palette" if group=="palette" else "field"),"drag target follows the "+group+" boundary")
 var leader_point=view.table.camera.unproject_position(view.table.zone_position("leader",0))
 expect(view.table.debug_drop_zone(leader_point,0)=="leader","leader slot takes precedence over adjacent field zones")
 view.table.set_top_down_view(false)
 expect(is_equal_approx(view.table.field_position("unit",0,6,0).x,-7.5),"3D unit row uses the wider battlefield")
 expect(is_equal_approx(view.table.field_position("item",0,4,0).x,-7.55) and view.table.WIDE_ZONES.support.has_point(Vector2(view.table.support_placement(0,2,0).at.x,view.table.support_placement(0,2,0).at.z)),"3D item and barrier rows follow the divided zones")
 expect(view.table.field_position("unit",0,6,0).z+item_half.y<view.table.field_position("item",0,4,0).z-item_half.y,"3D front and back rows do not overlap")
 print("2D UNIT LAYOUT: ",checks," checks; failures=",failures.size())
 app.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
