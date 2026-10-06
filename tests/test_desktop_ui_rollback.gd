extends "res://tests/support/ui_base.gd"

class PreviewSession:
 extends RefCounted
 var room={"undo_request":{},"undo_available":true}
 var replay_mode=false
 var read_only=false
 var connected=true
 var paused=false
 func ended() -> bool:return false
 func can_act(_in_match: bool=false) -> bool:return true

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/desktop-ui-rollback-fixtures/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED
 root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 expect(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_KEEP,"PC keeps the original 16:9 canvas")
 expect(find_button(app.screen,"游戏教程").position==Vector2(96,422) and find_button(app.screen,"人机对战").position==Vector2(470,422),"main menu pairs tutorials and AI on the first row")
 expect(find_button(app.screen,"检查更新")==null,"main menu hides manual update check")
 app.settings()
 await process_frame
 expect(find_button(app.screen,"返回").position==Vector2(1430,32),"settings header uses its original position")
 var fullscreen=app.screen.get_children().filter(func(child):return child is CheckButton and child.text=="全屏显示")
 expect(fullscreen.size()==1 and fullscreen[0].position==Vector2(420,290),"settings controls use their original layout")
 app.setup()
 await process_frame
 expect(find_button(app.screen,"开始对战").position==Vector2(570,654),"match setup uses its original layout")
 app.editor()
 await process_frame
 expect(app.editor_ui==null,"PC deck editor uses the original three panels")
 expect(app.library.columns==1 and app.library_rows.size()==app.library_ids().size() and app.screen.find_child("LibraryPagination",true,false)==null,"PC warehouse keeps all matching rows in its original scrolling list")
 var pc_kind=app.screen.find_child("LibraryKindFilter",true,false)
 var pc_kinds=[]
 for i in range(pc_kind.item_count):pc_kinds.append(pc_kind.get_item_text(i))
 expect(pc_kinds==["全部","单位","普通单位","自机单位","符卡","普通符卡","道具","结界"] and pc_kind.position==Vector2(1252,190),"PC type filter keeps its original options and position")
 expect(app.color_buttons.keys()==["全部","红","蓝","绿","黄","黑"] and app.color_buttons.values().all(func(choice):return choice.position.y==142),"PC color filters remain in their original horizontal row")
 expect(app.library_query_filters("自机符卡").is_empty() and app.library_query_filters("红自机符卡").is_empty(),"Android spell category does not change PC deck search parsing")
 expect(app.deck_canvas.position==Vector2(334,126),"deck canvas uses its original position")
 expect(app.main_card_rect(0)==Rect2(154,4,67,97),"deck cards use the original ten column grid")
 expect(find_button(app.screen,"打开 deck 文件夹")!=null,"original deck folder action remains available")
 expect(find_button(app.screen,"导入代码")!=null,"original import action remains available")
 app.begin_battle(true)
 view=app.duel_view
 await settle()
 view.render()
 await process_frame
 expect(view.STAGE==Rect2(0,0,1600,900),"battle uses the original canvas")
 expect(view.HAND==Rect2(246,663,1108,232),"hand uses the original region")
 var tools_menu=view.hud.get_node("BattleTools") as Button
 expect(tools_menu!=null and tools_menu.position==Vector2(1408,12) and view.observe_button.position==Vector2(1248,12),"battle toolbar aligns observation and grouped actions")
 var history_button=find_button(view.hud,"对局记录")
 var hand_badge=view.hud.get_node("OpponentHandCount")
 expect(find_button(view.hud,"设置")==null and history_button!=null and history_button.get_global_rect().end.x<hand_badge.get_global_rect().position.x,"battle history sits to the left of the opponent hand counter")
 var labels=[]
 tools_menu.pressed.emit();await process_frame
 for action in app.menu_popup.actions:labels.append(action.text)
 expect(labels.has("设置") and not labels.has("对局记录") and labels.has("视角复原") and labels.has("单位自动排序"),"desktop battle tools keep secondary actions grouped")
 app.close_menu_popup()
 view.browse_zone(0,"grave")
 expect(hand_badge.get_global_rect().position.y>view.browser_panel.get_global_rect().end.y,"hand counter moves below an overlapping pile popup")
 view.close_debug()
 expect(hand_badge.position==view.OPPONENT_HAND_COUNT.position,"hand counter returns when the popup closes")
 view.open_history()
 expect(view.history_panel.get_global_rect().end.x<hand_badge.get_global_rect().position.x,"battle history panel stays left of the hand counter")
 view.close_history()
 view.set_process(false)
 view.network_session=PreviewSession.new()
 var online_actions=view.responsive.tools_actions()
 expect(online_actions.any(func(action):return action[0]=="悔棋" and not action[2]),"PC undo is available from more actions")
 view.render_undo()
 expect(find_button(view.hud,"悔棋")==null,"PC has no separate undo button")
 view.observe_rewind({"sequence":41,"rewinds":[{"id":41,"from":view.local_seat}]})
 var paused_until=view.undo_auto_pause_until
 expect(paused_until-Time.get_ticks_msec()>3900,"approved undo pauses the requester's automatic actions for four seconds")
 view.observe_rewind({"sequence":41,"rewinds":[{"id":41,"from":view.local_seat}]})
 expect(view.undo_auto_pause_until==paused_until,"repeated snapshot does not restart the pause")
 view.observe_rewind({"sequence":42,"rewinds":[{"id":42,"from":1-view.local_seat}]})
 expect(view.undo_auto_pause_until==paused_until,"opponent undo does not pause this side")
 var previous_phase=view.engine.phase
 var previous_active=view.engine.active
 app.auto_camera_focus=true
 view.engine.phase="possession";view.engine.active=1-view.local_seat
 expect(view.required_camera_focus()==-1,"opponent possession keeps the PC camera unchanged")
 view.engine.phase=previous_phase;view.engine.active=previous_active
 print("DESKTOP UI ROLLBACK: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
