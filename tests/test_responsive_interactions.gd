extends "res://tests/support/ui_base.gd"

func frames():
 for i in range(6):await process_frame

func touch_tap(point: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/android-responsive/"+name+".png")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-responsive/interaction-fixtures")
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(2160,1080);root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.layout_dpi_override=360;app.layout_safe_override=Rect2(60,0,2076,1056)
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.refresh_ui_metrics();app.load_legacy_test_decks();app.show_card_inspection=true
 app.draft=app.decks[app.player_choice].duplicate(true);app.editor();await frames()
 app.alert("这是确认按钮与安全区域检查。","提示")
 await frames()
 var dialog: AcceptDialog=app.get_children().filter(func(child):return child is AcceptDialog).back()
 print("DIALOG ",dialog.get_ok_button().text," size=",dialog.get_ok_button().size," min=",dialog.get_ok_button().custom_minimum_size," hit=",app.ui_metrics.hit)
 await shot("android-2160x1080-confirmation")
 expect(dialog.get_ok_button().size.x>=app.ui_metrics.hit and dialog.get_ok_button().size.y>=app.ui_metrics.hit,"dialog confirmation keeps its text and 48dp area")
 dialog.hide();dialog.queue_free();await frames()
 await shot("android-2160x1080-editor")
 expect(app.editor_ui.center.size.x>app.editor_ui.catalogue.size.x-32,"18:9 gives the deck the largest region")
 app.open_leader_picker();await frames()
 var leader_popup=app.get_node("LeaderPicker")
 var selector=leader_popup.find_child("CardNameSearchPanel",true,false)
 expect(app.ui_metrics.safe.grow(2).encloses(selector.get_parent().get_global_rect()),"leader search fits safe area")
 expect(find_button(leader_popup,"设为自机").size.y>=app.ui_metrics.hit,"leader confirmation is a full touch target")
 await shot("android-2160x1080-leader-picker")
 leader_popup.queue_free();await frames()
 app.begin_battle(true);view=app.duel_view;e=view.engine;view.set_process(false)
 await settle();await frames()
 await shot("android-2160x1080-battle")
 var first=e.players[0].hand[0].uid
 var tile=view.hand_nodes[first]
 await click(tile.get_global_rect().get_center())
 expect(first in view.selection,"touch-mode mouse release selects a mulligan card")
 expect(find_button(view.ui,"调度 1 张")!=null,"selection updates the prominent phase action")
 view.inspect_card(tile.card_id,first);await frames()
 expect(view.inspection.visible,"card details can open without hover")
 var close=find_button(view.inspection,"关闭详情")
 expect(close!=null and not view.touch_camera_available(close.get_global_rect().get_center()),"inspection close target is not stolen by camera gestures")
 await click(close.get_global_rect().get_center());expect(not view.inspection.visible,"card inspection closes by touch")
 for i in range(10):e.players[0].palette.append(e.make_card(app.decks[app.player_choice].main[i],0,"palette"))
 view.selection=[];e.phase="possession";e.pending={"kind":"possession","owner":0};view.render();await settle();await frames()
 expect(is_instance_valid(view.android_palette_panel),"possession opens the palette")
 expect(view.android_palette_panel.get_global_rect().encloses(view.android_palette_scroll.get_global_rect()),"palette scroll stays inside its popup")
 var confirm=find_button(view.ui,"确定凭依");var skip=find_button(view.ui,"跳过凭依")
 expect(confirm!=null and skip!=null and not confirm.get_global_rect().intersects(skip.get_global_rect()),"possession actions do not overlap")
 expect(not skip.get_global_rect().intersects(view.android_back_button.get_global_rect()),"possession and back remain separate")
 await shot("android-2160x1080-possession")
 var toggle=view.hud.get_node("AndroidPaletteToggle0")
 var toggle_point=toggle.get_global_rect().get_center()
 expect(view.android_palette_toggle_at(toggle_point)==0,"palette touch uses the actual responsive button rectangle")
 await touch_tap(toggle_point)
 expect(view.android_palette_owner==-1,"native touch closes the palette without a duplicate mouse toggle")
 await touch_tap(toggle_point)
 expect(view.android_palette_owner==0,"native touch reopens the palette")
 view.settings_menu();await frames()
 var resume=find_button(view.modal_root,"继续游戏")
 expect(resume.size.y>=app.ui_metrics.hit,"battle settings use the shared touch size")
 await shot("android-2160x1080-settings")
 await click(resume.get_global_rect().get_center());expect(not view.modal,"battle settings return to the active choice")
 # Resize a live duel, retaining selections and the engine object.
 var engine_before=view.engine
 root.size=Vector2i(1280,720);app.layout_dpi_override=240;app.layout_safe_override=Rect2(40,0,1220,704)
 await frames();await frames()
 expect(view.engine==engine_before and e.phase=="possession","resize keeps the active game and phase")
 expect(app.ui_metrics.safe.grow(2).encloses(view.android_back_button.get_global_rect()),"resized back button follows new safe insets")
 view.browse_zone(0,"deck");await frames()
 expect(app.ui_metrics.safe.encloses(view.browser_panel.get_global_rect()),"mobile pile browser fits the safe area")
 expect(find_button(view.browser_panel,"×").size.y>=app.ui_metrics.hit,"pile browser close has a full touch target")
 await shot("android-1280x720-pile")
 view.close_debug();view.open_android_help();await frames()
 expect(find_button(view.modal_root,"返回对局").size.y>=app.ui_metrics.hit,"help close has a full touch target")
 view.close_overlay()
 clean(false)
 var attacker=put("39","field",0)
 var defenders=[put("39","field",1),put("53","field",1),put("48","field",1)]
 e.combat={"attacker":e.ref_target(attacker),"blockers":defenders.map(func(c):return e.ref_target(c))}
 e.pending={"kind":"damage_assignment","owner":0,"total":3}
 view.damage_dialog();await frames()
 var control=view.damage_controls[str(defenders[0].uid)]
 expect(control.plus.size.x>=app.ui_metrics.hit and control.minus.size.y>=app.ui_metrics.hit,"damage plus/minus use 48dp targets")
 await click(control.plus.get_global_rect().get_center())
 expect(view.damage_values[str(defenders[0].uid)]==1 and view.damage_remaining()==2,"responsive damage control preserves allocation behavior")
 await shot("android-1280x720-damage")
 print("RESPONSIVE INTERACTIONS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
