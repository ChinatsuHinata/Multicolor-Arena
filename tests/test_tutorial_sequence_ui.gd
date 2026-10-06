extends "res://tests/support/ui_base.gd"
const Runtime=preload("res://scripts/tutorial/runtime.gd")
var output="res://work/tutorial-sequence-ui"

func frames(count: int=4):
 for i in range(count):await process_frame

func fixture() -> Dictionary:
 return {"schema_version":1,"id":"sequence_ui","title":"固定战斗演示","initial_scenario":"board","start_step":"demo","completion":{"type":"always"},
  "scenarios":{"board":{"seed":42,"players":[
   {"leader":{"card_id":"70"},"deck_order":[{"card_id":"53"}],"hand":[{"card_id":"96","alias":"spell"}],"palette":[{"card_id":"70"},{"card_id":"53"}],"field":[{"card_id":"53","alias":"attacker"}]},
   {"leader":{"card_id":"70"},"deck_order":[{"card_id":"53"}],"field":[{"card_id":"35","alias":"target"},{"card_id":"53","alias":"blocker"}]}
  ]}},"steps":{"demo":{"type":"info","guide":{"text":"先使用符卡，再宣言攻击；对方按规定阻挡。演示结束后，可以重置再看一遍。"},"sequence":{"actions":[
   {"type":"cast","player":0,"card":{"alias":"spell"},"target":{"alias":"target"}},
   {"type":"pass_priority","player":1},{"type":"pass_priority","player":0},
   {"type":"attack","player":0,"card":{"alias":"attacker"}},
   {"type":"pass_priority","player":1},{"type":"pass_priority","player":0},
   {"type":"block","player":1,"cards":[{"alias":"blocker"}]},
   {"type":"pass_priority","player":0},{"type":"pass_priority","player":1},
   {"type":"pass_priority","player":0},{"type":"pass_priority","player":1}
  ]},"next":"done"},"done":{"type":"info","guide":{"text":"下一段讲解"},"next":"$complete"}}}

func shot(label: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label+".png"))

func play(flow,scene,label: String):
 var observed_animation=false;var observed_combat=false
 for i in range(1500):
  if not flow.playing_sequence():break
  var guide=scene.tutorial_guide
  expect(not guide.panel.visible and not guide.restore_button.visible,label+" hides dialogue and restore control during playback") if i==0 else null
  if view.tutorial_presentation_busy():
   var index=flow.sequence.index
   flow.tick(1.0/60.0)
   expect(flow.sequence.index==index,label+" waits for all presentation work") if not observed_animation else null
   observed_animation=true
  else:flow.tick(1.0/60.0)
  if view.table.combat_animating:observed_combat=true
  if i==20:await shot(label+"-playing")
  await process_frame
 expect(flow.running and not flow.playing_sequence(),label+" finishes: "+flow.last_error)
 expect(observed_animation and observed_combat,label+" plays both card and combat animations")
 var guide=scene.tutorial_guide
 expect(guide.panel.visible and guide.popup_open and guide.reset_button.visible and not guide.reset_button.disabled,label+" restores dialogue with enabled replay")
 expect(guide.reset_button.text=="重置演示" and guide.next_button.visible and not guide.next_button.disabled,label+" labels demonstration reset and allows next")
 expect(not view.tutorial_controls_enabled and guide.blocker.visible,label+" keeps battle input blocked after playback")
 expect(not view.tutorial_presentation_busy(),label+" final dialogue waits for the last animation")

func check(mobile: bool,external: bool):
 app.clear_page("tutorial_scene" if external else "battle");await frames()
 app.is_android=mobile;app.layout_dpi_override=360 if mobile else 0
 app.layout_safe_override=Rect2(40,12,1200,684) if mobile else Rect2()
 root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
 app.refresh_responsive_layout();await frames()
 var flow=Runtime.new();expect(flow.start(fixture(),Store.CARDS).is_empty(),"UI sequence starts")
 flow.set_process(false)
 var scene
 if external:
  scene=preload("res://scripts/tutorial/scene_view.gd").new();app.screen.add_child(scene);scene.begin(app,flow);view=scene.surface
 else:
  view=preload("res://scripts/duel_view.gd").new();view.tutorial_runtime=flow;app.screen.add_child(view);view.begin(app,{},{},0);scene=view
 flow.set_process(false)
 await frames()
 var label=("android" if mobile else "desktop")+("-external" if external else "-direct")
 expect(not scene.tutorial_guide.popup_open and not flow.next(),label+" automatically hides dialogue on entry and prevents skipping")
 scene.tutorial_guide.set_popup(true)
 expect(not scene.tutorial_guide.panel.visible,label+" cannot manually reopen a running demonstration")
 await click(view.project(view.table.visuals["card_"+str(flow.adapter.entity("attacker").uid)].global_position),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_id.is_empty(),label+" card details cannot cover a running demonstration")
 await play(flow,scene,label)
 await shot(label+"-finished")
 var final_game=flow.adapter.capture().game
 var button=scene.tutorial_guide.reset_button
 await click(button.get_global_rect().get_center());await frames()
 if external:view=scene.surface
 expect(flow.playing_sequence() and flow.sequence.index==0 and flow.adapter.entity("spell").zone=="hand",label+" replay button restores the start and begins again")
 await play(flow,scene,label+"-replay")
 expect(flow.adapter.capture().game==final_game,label+" UI replay repeats the exact final game")
 var guide=scene.tutorial_guide
 for control in [guide.next_button,guide.previous_button,guide.reset_button,guide.hide_button,guide.exit_button]:
  expect(guide.panel.get_global_rect().encloses(control.get_global_rect()),label+" dialogue contains "+control.name)
  var text_width=control.get_theme_font("font").get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x
  expect(text_width+control.get_theme_stylebox("normal").get_minimum_size().x<=control.size.x+1,label+" caption fits "+control.text)
 await click(guide.next_button.get_global_rect().get_center());await frames()
 expect(flow.current_step=="done" and not scene.tutorial_guide.reset_button.visible,label+" ordinary dialogue has no replay control")
 scene.queue_free();await frames();view=null

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.settings_path=output.path_join("missing-settings.json");app.account_session_path=output.path_join("missing-account.json")
 root.add_child(app);await frames()
 for mobile in [false,true]:
  for external in [false,true]:await check(mobile,external)
 print("TUTORIAL SEQUENCE UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
