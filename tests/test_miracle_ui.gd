extends "res://tests/support/ui_base.gd"
var output="res://work/miracle-ui"

func frames(count: int=8):
 for i in range(count):await process_frame

func tap_button(title: String):
 var button=find_button(view.ui,title)
 expect(button!=null,"Miracle button is visible: "+title)
 if button==null:return
 var at=button.get_global_rect().get_center()
 if not view.is_android:await click(at);return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await process_frame;await physics_frame

func draw_offer():
 clean()
 var card=put("106","deck");put("164","deck");put("164","deck")
 e.phase="prepare";e.advance_phase();view.render();await settle();await frames()
 return card

func check_flow(label: String):
 var card=await draw_offer()
 expect(e.stack.is_empty() and view.reveal_player.completed.is_empty(),label+" draw does not reveal before the owner decides")
 await tap_button("不展示");await frames()
 expect(e.pending.is_empty() and e.stack.is_empty() and card.zone=="hand" and view.reveal_player.completed.is_empty(),label+" refusing reveal leaves the card private in hand")
 card=await draw_offer()
 await tap_button("展示奇迹牌");await settle();await frames()
 expect(view.reveal_player.completed.any(func(event):return event.uid==card.uid and event.zone=="hand"),label+" public reveal animation presents the card from hand")
 expect(e.pending.is_empty() and e.stack.size()==1 and e.stack[0].kind=="ability" and card.zone=="hand",label+" after the animation the response window keeps the card in hand")
 expect(view.stack_panel.visible and view.stack_panel.tiles.size()==1 and view.hand_nodes.has(card.uid),label+" both the Miracle ability and the owner's hand card remain visible")
 resolve();view.render();await frames()
 expect(e.pending.get("trigger",{}).get("continuation",false) and card.zone=="hand",label+" both passes open the separate cast decision")
 await tap_button("确定");await settle();await frames()
 expect(card.zone=="stack" and e.stack.size()==1 and e.stack[0].kind=="card",label+" confirming the cast moves the card to its own stack entry")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 for android in [false,true]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  app.is_android=android;app.layout_dpi_override=240.0 if android else 0.0
  app.layout_safe_override=Rect2(60,0,1196,696) if android else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  await check_flow("Android" if android else "Desktop")
 print("MIRACLE UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
