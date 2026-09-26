extends "res://tests/support/ui_base.gd"

func add_unit(id: String,name: String,value: int,free: bool=false,token: bool=false) -> Dictionary:
 var info=e.cards["53"].duplicate(true)
 info.name=name;info.cost={"红":value} if value>0 else {}
 info.keywords=["不占战场格"] if free else []
 info.token=token;info.stackable=false;info.copy_source_id="53"
 e.cards[id]=info
 return put(id,"field")

func order_ids() -> Array:
 return view.table.ordered_units(0,e.players[0].field.filter(func(c):return e.is_unit(c))).map(func(c):return c.uid)

func icons_fit(icons: Array, card_size: Vector2) -> bool:
 var bounds=Rect2(-card_size/2.0,card_size)
 for i in range(icons.size()):
  var icon_rect=Rect2(icons[i].position,icons[i].size)
  if not bounds.encloses(icon_rect):return false
  for j in range(i):
   if icon_rect.intersects(Rect2(icons[j].position,icons[j].size)):return false
 return true

func run():
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_legacy_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 view.table.set_top_down_view(true)
 var high=add_unit("test_high","山妖",3)
 var derivative=add_unit("test_derivative","花妖衍生物",0,false,true)
 var ghost=add_unit("test_ghost","雾灵",0,true)
 var base=add_unit("test_base","花妖单位",2)
 var low=add_unit("test_low","小妖",1)
 view.render();await settle()
 expect(order_ids()==[high.uid,derivative.uid,ghost.uid,base.uid,low.uid],"initial unit order follows entry order")
 var leader=e.players[0].leader
 var leader_badge=view.card_badges.get("card_"+str(leader.uid),{})
 expect(leader_badge.get("icons",[]).size()==1 and leader_badge.icons[0].texture.resource_path.ends_with("leader_crown.svg"),"deck leader shows crown")
 var ghost_badge=view.card_badges.get("card_"+str(ghost.uid),{})
 expect(ghost_badge.get("icons",[]).size()==1 and ghost_badge.icons[0].texture.resource_path.ends_with("slot_ghost.svg"),"free slot unit shows ghost")
 var clone=put(leader.card_id,"field")
 view.render();await settle()
 expect(not view.card_badges["card_"+str(clone.uid)].has("icons"),"same card copied as a normal unit does not gain the deck leader crown")
 e.players[0].field.erase(clone)
 leader.zone="field";e.players[0].field.append(leader)
 view.render();await settle()
 expect(view.card_badges["card_"+str(leader.uid)].icons[0].texture.resource_path.ends_with("leader_crown.svg"),"deck leader keeps crown after moving onto battlefield")
 leader.modifiers=[{"不占战场格":true}]
 for marker_name in ["keiki","alice","yukari"]:
  e.cards[leader.card_id].copy_marker=marker_name
  view.render();await settle()
  var badge=view.card_badges["card_"+str(leader.uid)]
  var art_rect=view.projected_card_rect(view.table.visuals["card_"+str(leader.uid)])
  expect(badge.icons.size()==3 and badge.icons.all(func(icon):return icon.size==Vector2(28,28)) and badge.icons[2].texture.resource_path.ends_with(marker_name+".png"),marker_name+" portrait marker matches crown and ghost size")
  expect(icons_fit(badge.icons,art_rect.size),marker_name+" combined corner markers stay on the card without overlap")
  view.position_card_icons(badge.icons,Rect2(Vector2.ZERO,Vector2(66,95)))
  expect(badge.icons[2].position.y>badge.icons[0].position.y and icons_fit(badge.icons,Vector2(66,95)),marker_name+" corner markers wrap on a narrow card")
  view.update_badge_positions()
 e.cards[leader.card_id].erase("copy_marker");leader.erase("modifiers")
 e.players[0].field.erase(leader);leader.zone="leader"
 e.cards[ghost.card_id].keywords=[]
 ghost.modifiers=[{"不占战场格":true}]
 view.render();await settle()
 expect(view.card_badges["card_"+str(ghost.uid)].icons[0].texture.resource_path.ends_with("slot_ghost.svg"),"ghost follows a dynamic free slot effect")
 ghost.erase("modifiers")
 view.render();await settle()
 expect(not view.card_badges["card_"+str(ghost.uid)].has("icons"),"ghost disappears when the free slot effect ends")
 e.cards[ghost.card_id].keywords=["不占战场格"]
 view.sort_units();await settle()
 expect(order_ids()==[low.uid,base.uid,derivative.uid,high.uid,ghost.uid],"auto sort puts counted units left, groups matching unit and derivative, then free units")
 var before=e.revision
 var start=point(high.uid)
 var destination=point(low.uid)-Vector2(25,0)
 await drag(start,destination)
 await settle()
 expect(order_ids()==[high.uid,low.uid,base.uid,derivative.uid,ghost.uid],"dragging a unit changes its displayed order")
 expect(e.revision==before and e.players[0].field.map(func(c):return c.uid)==[high.uid,derivative.uid,ghost.uid,base.uid,low.uid],"display reorder does not change game state")
 var enemy_first=put("test_low","field",1)
 var enemy_second=put("test_high","field",1)
 view.table.set_top_down_view(false);view.render();await settle()
 await drag(point(enemy_second.uid),point(enemy_first.uid)+Vector2(25,0))
 await settle()
 expect(view.table.unit_order[1]==[enemy_second.uid,enemy_first.uid],"opponent units can also be rearranged in 3D view")
 await click(point(high.uid))
 expect(view.inspect_uid==high.uid or view.action_menu_open or view.attack_preview_uid==high.uid,"clicking a unit still opens its normal interaction")
 clean(true)
 view.table.unit_order={0:[],1:[]}
 app.debug_drag_to_field=false
 var debug_first=put("53","field")
 var debug_second=put("54","field")
 view.render();await settle()
 var debug_revision=e.revision
 await drag(point(debug_second.uid),point(debug_first.uid)-Vector2(25,0))
 await settle()
 expect(debug_second.zone=="field" and view.table.unit_order[0]==[debug_second.uid,debug_first.uid] and e.revision==debug_revision,"test mode drag onto unit row reorders without changing game state or requiring field-drop setting")
 await drag(point(debug_second.uid),pile_point("grave"))
 await settle()
 expect(debug_second.zone=="grave" and debug_second not in e.players[0].field,"same test mode gesture still moves a unit to another zone")
 print("UNIT ORDER UI: ",checks," checks; failures=",failures.size())
 app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
