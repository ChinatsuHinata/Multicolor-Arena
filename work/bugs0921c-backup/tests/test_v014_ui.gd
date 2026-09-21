extends "res://tests/test_v012_ui.gd"
func capture(name:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v014/"+name+".png")
func await_reveal(serial:int):
 for i in range(100):
  if view.reveal_player.current.get("serial",-1)==serial and not view.reveal_player.public_uids.is_empty():return
  await create_timer(0.05).timeout
 expect(false,"reveal reached visible face "+str(serial))
func finish_reveals():
 for i in range(240):
  if not view.revealing():return
  await create_timer(0.05).timeout
 expect(false,"reveal queue completes")
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean(true)
 var own=[];var support=[];var items=[];var palette=[]
 for who in range(2):
  for id in ["50","51","52","53","54","55"]:own.append(put(id,"field",who))
  for id in ["164","165","166","167"]:items.append(put(id,"field",who))
  for id in ["170","spell-fdf-040","field-rei-003"]:support.append(put(id,"field",who))
  for id in ["164","165","166","167","168","169","70","68"]:palette.append(put(id,"palette",who))
  for id in ["50","96","70","164"]:put(id,"hand",who)
  for i in range(12):put("50" if i%2==0 else "96","grave",who)
 var melody=put("spell-fdf-042","field");view.render();await settle()
 expect(view.STAGE.get_center().x==800 and view.HAND.get_center().x==800,"stage and hand centered on viewport")
 var all=own+support+items+palette
 expect(all.all(func(c):return view.table.descriptors["card_"+str(c.uid)].scale==Vector3.ONE*view.table.FIELD_SCALE),"unit item support and palette cards share dimensions")
 expect(support.all(func(c):return is_equal_approx(view.table.descriptors["card_"+str(c.uid)].rotation.y,PI/2)),"barriers and timed spells lie landscape")
 expect(view.table.descriptors["card_"+str(melody.uid)].at.x>8 and is_equal_approx(view.table.descriptors["card_"+str(melody.uid)].rotation.y,PI/2),"own melody uses right central landscape slot")
 e.players[0].field.erase(melody);melody.owner=1;e.players[1].field.append(melody);view.render();await settle()
 expect(view.table.descriptors["card_"+str(melody.uid)].at.x< -8,"opposing melody uses left central slot")
 var camera=view.table.camera.position
 for button in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
  var event=InputEventMouseButton.new();event.pressed=true;event.button_index=button;view.table.pointer(event)
 expect(view.table.camera_distance==0.77 and view.table.camera.position==camera,"camera locked at nearest distance")
 for corner in [Vector3(-11.5,0,-8),Vector3(11.5,0,-8),Vector3(-11.5,0,8),Vector3(11.5,0,8)]:expect(view.STAGE.has_point(view.project(corner)),"entire mat within fixed camera viewport "+str(corner))
 for c in palette:
  expect(view.STAGE.encloses(view.projected_card_rect(view.table.visuals["card_"+str(c.uid)])),"palette card is fully visible "+str(c.uid))
 var unit=own[0];unit.plus_counters=3;unit.minus_counters=2;unit.leader_counters=1;unit.timer=2;unit.poverty=1;unit.scare=2;unit.courage=4;unit.dream=1;unit.madness=2;unit.color_counters=["红","红","黄"]
 view.inspect_card(unit.card_id,unit.uid);view.browse_zone(1,"grave");await settle()
 expect(view.browser_panel.size==view.inspection.size and view.browser_cards.columns==2,"matching side panels and two-column pile browser")
 var text=view.inspection_text.get_parsed_text()
 for part in ["+3/+3/+3","-2/-2","自机：1","计时：2","贫穷：1","惊吓：2","勇气等级：4","梦违：1","狂乱：2","红色指示物：2","黄色指示物：1"]:expect(part in text,"counter preview "+part)
 unit.plus_counters=5;view.update_inspection();expect("+5/+5/+5" in view.inspection_text.get_parsed_text(),"preview refreshes counter changes on same instance")
 await capture("battlefield-layout");view.close_debug();view.settings_menu();await settle();await capture("settings-center");view.close_overlay()
 clean();view.debug_mode=false;e.debug_enabled=false
 var hand=put("96","hand",1);put("50","hand",1);put("70","hand",1)
 var top=put("99","deck",1);var bottom=put("170","deck",1)
 view.render();await settle();expect(view.enemy_nodes[hand.uid].hidden_card,"opposing hand starts concealed")
 e.reveal_card(hand);e.reveal_card(top,"top");e.reveal_card(bottom,"bottom");e.reveal_card(top,"top")
 view.render();var revision=e.revision;await await_reveal(1)
 expect(not view.enemy_nodes[hand.uid].hidden_card and view.reveal_player.public_uids==[hand.uid],"only selected hand card temporarily public")
 expect(view.enemy_nodes[e.players[1].hand[1].uid].hidden_card,"other hand remains hidden")
 await capture("hand-reveal");await click(Vector2(1480,800));expect(e.revision==revision,"revealing pauses further actions")
 await await_reveal(2);expect(view.enemy_nodes[hand.uid].hidden_card,"hand returns to private after the presentation")
 await capture("top-reveal");await await_reveal(3);await capture("bottom-reveal");await finish_reveals()
 expect(view.reveal_player.completed.size()==4,"every repeated and bottom reveal animates once")
 expect(view.reveal_player.completed.all(func(row):return row.duration==0.5),"each flip has a half-second presentation timeline")
 expect(not view.revealing() and view.reveal_player.public_uids.is_empty(),"reveal completion restores interaction")
 expect(e.players[1].hand.has(hand) and e.players[1].deck.has(top) and e.players[1].deck.has(bottom),"animation never changes logical zones")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"UI leaves saved decks unchanged")
 print("V014_UI: ",checks," checks; ",failures," failures");quit(0 if failures.is_empty() else 1)
