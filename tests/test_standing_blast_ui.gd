extends "res://tests/support/ui_base.gd"
## Actual hide/restore input for the standing barrier and its unit targets.
var output="res://work/standing-blast"

func frames(count: int=8):
 for i in range(count):await process_frame

func tap(at: Vector2):
 if not view.is_android:await click(at);await frames();return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames();await physics_frame

func tap_button(button: Button):
 if button!=null:await tap(button.get_global_rect().get_center())

func ability_button():
 if not is_instance_valid(view.android_choice_panel):return null
 var rows=view.android_choice_panel.find_child("ActionChoiceGrid",true,false)
 if rows==null:return null
 for button in rows.get_children():
  if button.get_meta("action_type","")=="extension":return button
 return null

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func hide_restore(label: String):
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel),label+" panel exists before hiding")
 if not is_instance_valid(panel):return
 await tap_button(find_button(panel,"隐藏"))
 expect(not is_instance_valid(view.android_choice_panel) and is_instance_valid(view.android_choice_restore),label+" hide collapses the panel")
 if not is_instance_valid(view.android_choice_restore):return
 await tap_button(view.android_choice_restore)
 expect(is_instance_valid(view.android_choice_panel) and not is_instance_valid(view.android_choice_restore),label+" expand restores the panel")

func check_flow(label: String):
 clean()
 var barrier=put("field-rei-004","field")
 var own=put("53","field")
 var enemy=put("53","field",1)
 var leader=put("70","field",1)
 var tapped=put("53","field",1);e.tap_card(tapped)
 var reset=put("53","field",1);e.tap_card(reset);reset.tapped=false
 var old=put("53","field",1);old.tapped=true;old.tapped_turn=e.turn-1
 var item=put("167","field")
 var options=e.activation_options(barrier,"standing_blast")
 for unit in [own,enemy,leader,tapped,reset,old]:
  expect(e.ref_target(unit) in options,label+" legal target includes unit "+str(unit.uid))
 expect(e.ref_target(item) not in options and not options.any(func(t):return t.has("player")),label+" targets stay limited to battlefield units")
 view.render();view.focus_android_camera(false);await settle();await frames()
 await shot(label+"-board")
 if "--diagnose" in OS.get_cmdline_user_args():
  var at=view.target_rect(e.ref_target(barrier)).get_center()
  var surface=view.android_card_touch.surface_at(view.ui,at)
  print("STANDING INPUT ",label," ",JSON.stringify({"at":str(at),"rect":str(view.target_rect(e.ref_target(barrier))),"hit":view.touch_card_at(at),"surface":str(surface.get_path()) if surface!=null else "","hand":str(view.HAND),"safe":str(app.ui_metrics.safe)}))
 await tap(view.target_rect(e.ref_target(barrier)).get_center())
 expect(view.action_menu_open and view.android_action_uid==barrier.uid,label+" clicking barrier opens its ability menu")
 await hide_restore(label+" ability menu")
 if not is_instance_valid(view.android_choice_panel):return
 var menu_cancel=find_button(view.android_choice_panel,"取消")
 expect(menu_cancel!=null and view.android_choice_panel.get_global_rect().encloses(menu_cancel.get_global_rect()),label+" menu cancellation is visible inside the restored panel")
 await shot(label+"-actions")
 if menu_cancel!=null:
  await tap_button(menu_cancel)
  expect(not view.action_menu_open and barrier.zone=="field",label+" restored menu can close without paying")
  await tap(view.target_rect(e.ref_target(barrier)).get_center())
 var ability=ability_button()
 expect(ability!=null and not ability.disabled,label+" restored menu offers the standing blast ability")
 if ability==null or ability.disabled:return
 await tap_button(ability)
 expect(view.local.get("key","")=="standing_blast" and view.picker_active(),label+" restored ability button enters target selection")
 if view.local.is_empty():return
 await hide_restore(label+" target choice")
 var cancel=find_button(view.android_choice_panel,"取消使用")
 expect(cancel!=null,label+" restored target choice offers cancellation")
 if cancel!=null:expect(view.android_choice_panel.get_global_rect().encloses(cancel.get_global_rect()),label+" cancellation fits inside the target panel")
 for unit in [own,enemy,leader,tapped,reset,old]:
  if not view.picker.path.is_empty():
   await tap_button(find_button(view.android_choice_panel,"重选"))
  await tap(view.target_rect(e.ref_target(unit)).get_center())
  expect(view.picker.ready() and view.local.get("target",{}).get("uid",0)==unit.uid,label+" actual battlefield click selects unit "+str(unit.uid))
 await hide_restore(label+" selected target")
 expect(view.picker.ready() and view.local.get("target",{}).get("uid",0)==old.uid,label+" restored target keeps the selection")
 var prompt=view.android_choice_panel.get_node("BoardTargetPrompt") as Label
 if "--diagnose" in OS.get_cmdline_user_args():print("STANDING PROMPT ",label," ",JSON.stringify({"panel":str(view.android_choice_panel.get_global_rect()),"prompt":str(prompt.get_global_rect()),"cancel":str(find_button(view.android_choice_panel,"取消使用").get_global_rect()),"font":prompt.get_theme_font_size("font_size"),"lines":prompt.get_line_count(),"line_height":prompt.get_line_height(),"minimum":str(prompt.get_minimum_size()),"text":prompt.text}))
 expect(prompt.size.y+1>=prompt.get_line_height()*prompt.get_line_count(),label+" restored prompt shows the selected target without clipping")
 expect(not prompt.get_global_rect().intersects(find_button(view.android_choice_panel,"取消使用").get_global_rect()),label+" target description leaves cancellation clear")
 await shot(label+"-target")
 cancel=find_button(view.android_choice_panel,"取消使用")
 if cancel!=null:
  await tap_button(cancel)
  expect(view.local.is_empty() and barrier.zone=="field" and e.stack.is_empty(),label+" cancellation spends no sacrifice or ability")
 else:
  view.right_cancel();await frames()
  expect(view.local.is_empty(),label+" right cancel exits the target choice")
 await tap(view.target_rect(e.ref_target(barrier)).get_center())
 await tap_button(ability_button())
 expect(is_instance_valid(view.android_choice_panel) and not is_instance_valid(view.android_choice_restore),label+" reopening a cancelled ability shows its target prompt")
 await tap(view.target_rect(e.ref_target(enemy)).get_center())
 var confirm=find_button(view.android_choice_panel,"发动")
 expect(confirm!=null and not confirm.disabled,label+" an untapped enemy can be submitted")
 await tap_button(confirm)
 expect(view.local.is_empty() and barrier.zone=="grave" and e.stack.any(func(entry):return entry.get("effect","")=="standing_blast" and entry.target.get("uid",0)==enemy.uid),label+" submitting queues the real ability against an untapped unit")
 # Verify cancellation is also available when no unit can be selected.
 clean();barrier=put("field-rei-004","field")
 view.render();await settle();await frames();view.open_actions(barrier);await frames()
 await hide_restore(label+" empty battlefield menu")
 ability=ability_button()
 expect(ability!=null and ability.disabled,label+" an empty battlefield disables the ability")
 cancel=find_button(view.android_choice_panel,"取消")
 expect(cancel!=null,label+" restored empty menu offers cancellation")
 if cancel!=null:
  await tap_button(cancel)
  expect(not view.action_menu_open and view.android_action_uid==0,label+" menu cancellation closes the choice")
 else:view.right_cancel();await frames()

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();app.settings_path=output.path_join("settings.json");root.add_child(app);await frames();app.load_legacy_test_decks()
 # Keep draggable zone shortcuts away from card centers; their oversized
 # hit regions are verified separately by test_android_zone_shortcuts.gd.
 app.android_zone_shortcut_positions={"own_grave":[0,0.2],"enemy_grave":[0,0.45],"exile":[0,0.7]}
 var fixtures=[{"size":Vector2i(1600,900),"dpi":0.0},{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(1280,720),"dpi":320.0}]
 if "--android-only" in OS.get_cmdline_user_args():fixtures=fixtures.filter(func(fixture):return fixture.dpi>0)
 if "--dpi320-only" in OS.get_cmdline_user_args():fixtures=fixtures.filter(func(fixture):return fixture.dpi==320)
 for fixture in fixtures:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  var mobile=fixture.dpi>0
  app.is_android=mobile;app.layout_dpi_override=fixture.dpi
  root.size=fixture.size
  app.layout_safe_override=Rect2(60,0,1196,696) if mobile else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  for top_down in [false,true]:
   view.table.set_top_down_view(top_down);view.render();await settle()
   await check_flow(("android-dpi%d" % fixture.dpi if mobile else "pc")+("-2d" if top_down else "-3d"))
 app.queue_free();await frames()
 print("STANDING BLAST UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
