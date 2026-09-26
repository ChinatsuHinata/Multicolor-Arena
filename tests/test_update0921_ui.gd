extends "res://tests/support/node_ui_base.gd"
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/update0921/ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.player_choice=0;app.ai_choice=1;app.begin_battle(true);await process_frame
 view=app.duel_view;view.set_process(false);e=view.engine;clean(true)
 view.render();await settle()
 expect(find_button(view.ui,"全响应")!=null and find_button(view.ui,"不响应")!=null,"two response buttons visible")
 expect(view.response_mode==view.ResponseMode.DEFAULT,"neither selected defaults")
 await press("全响应");expect(view.response_mode==view.ResponseMode.ON and find_button(view.ui,"全响应").button_pressed and not find_button(view.ui,"不响应").button_pressed,"all response selected exclusively")
 await press("不响应");expect(view.response_mode==view.ResponseMode.OFF and not find_button(view.ui,"全响应").button_pressed,"no response deselects all response")
 await press("不响应");expect(view.response_mode==view.ResponseMode.DEFAULT,"click selected toggle returns to default")
 e.players[0].coins=2;e.players[0].wards=[{"amount":3,"turn":-1}];e.players[1].coins=1
 var spell=put("new-eto-008","hand");var unit=put("new-loc-001","field")
 var c=e.make_card("new-eto-010",0,"stack");e.stack=[{"id":777,"kind":"card","card":c,"owner":0,"name":e.cards[c.card_id].name,"target":{"none":true}}]
 view.render();view.inspect_card(spell.card_id,spell.uid);await settle()
 expect("铜钱：2" in view.life_widgets[0].buffs.text and "防避：3" in view.life_widgets[0].buffs.text,"player buffs beside life")
 expect(view.life_widgets[0].buffs.position.x>view.life_widgets[0].button.position.x+view.life_widgets[0].button.size.x,"buffs to the right of health bar")
 expect(app.preview_texture(spell.card_id).get_width()>app.preview_texture(spell.card_id).get_height(),"landscape preview texture")
 expect(app.texture(spell.card_id).get_height()>app.texture(spell.card_id).get_width(),"hand and field remain portrait")
 var stack=view.get("stack_panel")
 if stack==null:
  for node in nodes_of_type(view,"Control"):
   if node.get_script()==preload("res://scripts/duel_stack.gd"):stack=node;break
 expect(stack!=null and stack.tiles[777].tile.size.x>stack.tiles[777].tile.size.y,"stack spell displayed landscape")
 await capture("update0921-battle")
 e.stack=[];view.inspect_card(unit.card_id,unit.uid);view.render();await settle()
 expect(app.preview_texture(unit.card_id).get_height()>app.preview_texture(unit.card_id).get_width(),"unit preview remains portrait")
 clean(true)
 var ward_unit=put("54","field")
 ward_unit.wards=[{"amount":1,"turn":-1},{"amount":3,"turn":-1}]
 e.damage_target(e.ref_target(ward_unit),2);view.render();await process_frame
 expect(view.modal and find_button(view.ui,"防避 1  ·  持续")!=null and find_button(view.ui,"防避 3  ·  持续")!=null,"mixed ward choices appear for controller")
 await press("防避 3  ·  持续")
 expect(e.pending.is_empty() and ward_unit.wards.size()==1 and ward_unit.wards[0].amount==1,"ward button resolves damage")
 app.editor();await process_frame
 app.draft.main=[]
 for i in range(50):app.draft.main.append("53")
 app.draft.leader="68";app.update_deck_rows();await process_frame
 var final=app.main_card_rect(49)
 expect(final.end.y<=509 and final.end.x<=854,"50 main cards fit within one-page area")
 expect(app.main_card_rect(0).position.x>150,"separate leader slot retained")
 app.selected="new-eto-008";app.update_preview();await process_frame
 expect(app.preview.get_child(0).get_child(0).texture.get_width()>app.preview.get_child(0).get_child(0).texture.get_height(),"deck editor preview landscape")
 await capture("update0921-editor")
 print("UPDATE0921 UI ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
