extends "res://tests/support/ui_base.gd"

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
 expect(find_button(app.screen,"人机对战    →").position==Vector2(96,422),"main menu uses its original button positions")
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
 expect(find_button(view.hud,"设置")==null and find_button(view.hud,"对局记录")==null,"secondary actions no longer crowd the battlefield")
 var labels=[]
 tools_menu.pressed.emit();await process_frame
 for action in app.menu_popup.actions:labels.append(action.text)
 expect(labels.has("设置") and labels.has("对局记录") and labels.has("视角复原") and labels.has("单位自动排序"),"battle tools keep the former actions available")
 app.close_menu_popup()
 print("DESKTOP UI ROLLBACK: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
