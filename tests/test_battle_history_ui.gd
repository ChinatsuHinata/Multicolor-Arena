extends "res://tests/support/ui_base.gd"
const Fixture=preload("res://tests/support/reveal_review_fixtures.gd")
var output="res://work/battle-history-ui"

func frames(count: int=6):
 for i in range(count):await process_frame

func pointer(at: Vector2,pressed: bool):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed
 root.push_input(event,true);await process_frame

func tap(at: Vector2):
 if view.is_android:await pointer(at,true);await pointer(at,false);await frames()
 else:await click(at);await frames()

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 expect(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"saved "+name)

func reveal_cells():return view.history_detail_panel.find_child("HistoryRevealedCards",true,false).get_children()

func check_android_menu_integration():
 view.render();await frames()
 var before=snapshot()
 view.settings_menu();await frames()
 var menu=view.android_battle_menu_root
 var contents=menu.find_child("BattleMenuContents",true,false)
 var volume=contents.find_child("RoomJoinVolumeControl",true,false)
 var slider=volume.get_node("RoomJoinVolume") as HSlider
 expect(volume.get_global_rect().position.x>=contents.get_global_rect().position.x-1 and volume.get_global_rect().end.x<=contents.get_global_rect().end.x+1,"android new reminder sound controls fit the combined menu")
 expect(volume.get_child_count()==3 and is_instance_valid(contents.find_child("PreviewRoomJoinSound",true,false)),"android sound title is separate while slider, percentage and preview remain available")
 var saved_volume=app.room_join_volume
 slider.value=37
 expect(is_equal_approx(app.room_join_volume,0.37) and volume.get_node("RoomJoinVolumeValue").text=="37%","android integrated sound slider retains the colleague's live setting callback")
 var preview=volume.get_node("PreviewRoomJoinSound") as Button
 expect(contents.get_global_rect().encloses(preview.get_global_rect()) and contents.get_global_rect().encloses(slider.get_global_rect()),"android sound slider and preview have fully visible hit targets")
 # Range controls receive Godot's emulated mouse input from native touch.
 var slider_touch=InputEventMouseButton.new();slider_touch.device=-1;slider_touch.button_index=MOUSE_BUTTON_LEFT;slider_touch.pressed=true
 slider_touch.position=slider.get_global_rect().position+Vector2(slider.size.x*0.72,slider.size.y/2)
 slider_touch.global_position=slider_touch.position
 root.push_input(slider_touch,true);await process_frame
 slider_touch=slider_touch.duplicate();slider_touch.pressed=false;root.push_input(slider_touch,true);await frames()
 expect(slider.value!=37 and is_equal_approx(app.room_join_volume,slider.value/100.0),"android emulated touch pointer changes notification volume inside the combined menu")
 await tap(preview.get_global_rect().get_center())
 expect(is_instance_valid(app.room_join_sound) and app.room_join_sound.playing,"android native touch previews the notification chime inside the combined menu")
 if is_instance_valid(app.room_join_sound):app.room_join_sound.stop()
 slider.value=saved_volume*100
 view.close_android_battle_menu()
 view.open_tools_menu();await frames()
 var history=find_button(view.android_battle_menu_root,"对局记录")
 history.pressed.emit();await frames()
 expect(not is_instance_valid(view.android_battle_menu_root) and view.history_open and is_instance_valid(view.history_panel),"android menu action opens the new history component after closing the menu")
 view.close_history();await frames()
 expect(view.history_panel==null and not view.observe_button.visible,"android closing history clears its panel and restores observation visibility")
 view.open_tools_menu();await frames();view.toggle_observation();await frames()
 var saved_camera=app.android_manual_camera
 app.android_manual_camera=true
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_MIDDLE;event.pressed=true
 event.position=view.STAGE.get_center();event.global_position=event.position
 root.push_input(event,true);await process_frame
 expect(view.observing and view.camera_dragging,"android hidden battle menu allows camera input while observing the battlefield")
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await process_frame
 app.android_manual_camera=saved_camera
 view.render();await frames()
 expect(not view.observing and view.android_battle_menu_root.visible,"android refreshing the duel restores a hidden menu instead of leaving an invisible blocker")
 view.toggle_observation()
 view.close_android_battle_menu();await frames()
 expect(not view.observing and not is_instance_valid(view.android_battle_menu_root) and snapshot()==before,"android closing a hidden menu restores duel controls without changing the game")

func check_history(prefix: String):
 clean();view.close_history()
 if view.is_android:await check_android_menu_integration()
 var fixture=Fixture.ability(e,0)
 var declaration=e.stack.back().history_index
 Fixture.resolve(e);Fixture.finish(e);e.confirm_revealed(1,e.pending.serial)
 e.presentation_events.clear();view.render();await frames();view.open_history();await frames()
 var entries=view.history_panel.find_child("HistoryEntries",true,false)
 var row
 for child in entries.get_children():
  if child.get_meta("history_entry",{}).text==e.history[declaration].text:row=child
 expect(row!=null,prefix+" original ability announcement appears in the history list")
 if row==null:return
 var scroll=view.history_panel.get_node("HistoryScroll")
 scroll.scroll_vertical=int(row.position.y);await frames()
 var before=snapshot();var saved_scroll=scroll.scroll_vertical
 var text=row.find_child("HistoryText",true,false)
 await tap(text.get_global_rect().get_center())
 expect(is_instance_valid(view.history_detail_panel),prefix+" clicking record text opens its details")
 if not is_instance_valid(view.history_detail_panel):return
 expect(reveal_cells().size()==3 and reveal_cells().map(func(cell):return cell.get_meta("history_art").card_id)==fixture.shown.map(func(c):return c.card_id),prefix+" ability details show every revealed card in order")
 expect(reveal_cells().all(func(cell):return cell.get_child(0).get_meta("history_display_id")!="back"),prefix+" historical reveals remain public after confirmation")
 var panel=view.history_detail_panel
 expect(app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()) and panel.get_global_rect().encloses(panel.get_node("HistoryDetailBack").get_global_rect()),prefix+" detail panel and return button fit the safe area")
 expect(snapshot()==before,prefix+" opening details does not change the duel")
 await shot(prefix+"-ability-details")
 var card=reveal_cells()[0].get_child(0)
 var inspection_scroll=panel.get_node("HistoryDetailScroll")
 inspection_scroll.scroll_vertical=maxi(0,int(card.get_global_rect().position.y-inspection_scroll.get_global_rect().position.y))
 await frames()
 if view.is_android:
  await pointer(card.get_global_rect().get_center(),true);await create_timer(1.12).timeout;await pointer(card.get_global_rect().get_center(),false)
 else:await click(card.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_id==fixture.shown[0].card_id and view.inspect_uid==0,prefix+" card inspection uses the historical snapshot")
 view.inspect_id="";view.update_inspection()
 await tap(panel.get_node("HistoryDetailBack").get_global_rect().get_center())
 expect(view.history_open and not is_instance_valid(view.history_detail_panel) and scroll.scroll_vertical==saved_scroll,prefix+" returning restores the list at the same scroll position")
 await tap(row.get_global_rect().position+Vector2(24,12))
 expect(is_instance_valid(view.history_detail_panel),prefix+" the record background also opens details")
 if view.is_android:view.android_back()
 else:
  var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;root.push_input(escape,true)
 await frames()
 expect(view.history_open and not is_instance_valid(view.history_detail_panel),prefix+" back or Escape closes only the entry detail")
 view.close_history();await frames()

 clean()
 e.history=[{"turn":4,"phase":"main","text":"长记录。".repeat(60),"art":[]},{"turn":4,"phase":"main","text":"隐藏牌移动","art":[{"card_id":"106","owner":1,"hidden":true,"art_id":"private-art"}]}]
 view.render();view.open_history();await frames()
 entries=view.history_panel.find_child("HistoryEntries",true,false)
 await tap(entries.get_child(0).get_global_rect().get_center())
 var related=view.history_detail_panel.find_child("HistoryRelatedCards",true,false)
 expect(related.get_child(0).get_child(0).get_meta("history_display_id")=="back" and related.get_child(0).get_child(1).text=="未公开",prefix+" hidden record detail exposes neither name nor artwork")
 view.close_history_entry()
 scroll=view.history_panel.get_node("HistoryScroll");scroll.scroll_vertical=10000;await frames()
 row=entries.get_child(1)
 expect(row.get_global_rect().encloses(row.find_child("HistoryText",true,false).get_global_rect()),prefix+" long record text expands inside its row")
 view.open_history_entry(e.history[0]);await frames()
 expect(view.history_detail_panel.find_child("HistoryDetailText",true,false).text==e.history[0].text,prefix+" details retain the complete record text")
 view.close_history();await frames()

 clean()
 var cards=[]
 for i in range(18):cards.append({"card_id":["spell-fdf-055","character-soi-006","121"][i%3],"owner":0,"hidden":false})
 e.history=[{"turn":8,"phase":"main","text":"大量展示","art":[],"revealed_cards":cards}]
 view.render();view.open_history();await frames()
 row=view.history_panel.find_child("HistoryEntries",true,false).get_child(0)
 await tap(row.get_global_rect().get_center())
 expect(reveal_cells().size()==18,prefix+" large batches retain all same-name copies")
 var detail_scroll=view.history_detail_panel.get_node("HistoryDetailScroll")
 if view.is_android:
  var at=detail_scroll.get_global_rect().get_center();await pointer(at,true)
  var drag_event=InputEventScreenDrag.new();drag_event.index=0;drag_event.position=at-Vector2(0,170);drag_event.relative=Vector2(0,-170)
  root.push_input(drag_event,true);await process_frame;await pointer(drag_event.position,false)
 else:detail_scroll.scroll_vertical=10000
 await frames()
 expect(detail_scroll.scroll_vertical>0 and is_instance_valid(view.history_detail_panel),prefix+" scrolling reveals more cards without navigating away")
 var count=reveal_cells().size()
 await shot(prefix+"-all-cards-scrolled")
 expect(count==18 and e.history[0].revealed_cards==cards,prefix+" browsing preserves every card snapshot")
 view.close_history();await frames()

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
  await check_history("android" if android else "desktop")
 print("BATTLE HISTORY UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
