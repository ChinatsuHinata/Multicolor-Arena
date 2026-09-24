extends "res://tests/test_bugs0921_ui.gd"
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/v11/ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 var expected_version="VERSION "+str(ProjectSettings.get_setting("application/config/version"))
 expect(nodes_of_type(app,"Label").any(func(n):return n.text==expected_version),"主菜单显示当前项目版本")
 app.player_choice=0;app.ai_choice=1;app.begin_battle(true);await process_frame
 view=app.duel_view;view.set_process(false);e=view.engine;clean(true)
 var leader=e.players[0].leader;e.enter_field(leader,0);e.pending={};e.triggers=[]
 e.Roster.blink_now(e,[leader]);e.pump_choices();view.render();await settle()
 expect(find_button(view.ui,"移除游戏")!=null and find_button(view.ui,"送入墓地")==null,"境界对自机显示正确去向按钮")
 await capture("v11-leader-choice")
 await press("移除游戏");await settle()
 expect(leader.zone=="field","点击移除游戏后境界返回战场")
 clean(true)
 var c=e.make_card("spell-fdf-051",0,"stack")
 var entry={"kind":"card","card":c,"owner":0,"target":{"picks":[[]],"x":2},"name":e.cards[c.card_id].name}
 e.Cat.Spells.copy_x_menu(e,entry);view.render();await settle()
 expect(nodes_of_type(view.ui,"Button").any(func(n):return "停止" in n.text),"复制菜单展示停止选项")
 e.choose_effect(e.pending.options[0]);view.render();await settle()
 expect(e.pending.trigger.effect=="cat:spell_copy","进入复制目标选择")
 view.right_cancel();await settle()
 expect(e.pending.trigger.effect=="cat:copy_x","右键返回复制模式菜单")
 await capture("v11-copy-menu")
 e.choose_effect({"none":true,"mode":"停止","copy_stop":true});view.render();await settle()
 expect(e.pending.is_empty(),"停止后正常进行对局")
 app.editor();await process_frame;app.query="摩多罗";app.update_library();await process_frame
 expect(app.library.get_child_count()==1,"组卡器摩多罗只显示一张")
 expect(is_instance_valid(app.library_sort_choice) and app.library_sort_choice.position.x>1238 and app.library_sort_choice.position.y>72,"排序菜单位于右侧卡库")
 app.query="梦";app.update_library();await process_frame
 var deck_before=JSON.stringify([app.draft.main,app.draft.side,app.draft.leader])
 var dirty_before=app.dirty
 app.library_sort_choice.select(1);app.library_sort_choice.item_selected.emit(1)
 var color_values=[]
 for row in app.library.get_children():color_values.append(app.library_card_color_value(row.card_id))
 var color_sorted=color_values.size()>5
 for i in range(1,color_values.size()):
  if color_values[i]<color_values[i-1]:color_sorted=false
 expect(color_sorted,"颜色值排序作用于数据库卡牌列表")
 app.library_sort_choice.select(2);app.library_sort_choice.item_selected.emit(2)
 var names=[]
 for row in app.library.get_children():names.append(Store.CARDS[row.card_id].name)
 var name_sorted=names.size()>5
 for i in range(1,names.size()):
  if names[i-1].naturalnocasecmp_to(names[i])>0:name_sorted=false
 expect(name_sorted,"名字排序作用于数据库卡牌列表")
 expect(JSON.stringify([app.draft.main,app.draft.side,app.draft.leader])==deck_before and app.dirty==dirty_before,"切换卡库排序不修改卡组或未保存状态")
 app.query="摩多罗";app.update_library();await process_frame
 await capture("v11-okina-editor")
 app.query=""
 var complete_library=app.library_ids()
 expect(complete_library.has("character-ucs-020") and complete_library.has("character-ucs-021") and complete_library.has("token-ucs-099"),"卡库展示梦违与衍生物")
 app.query="梦违"
 var dream_ids=app.library_ids()
 expect(dream_ids.size()==7 and dream_ids.all(func(id):return not Store.CARDS[id].constructible and not Store.CARDS[id].token),"搜索梦违展示全部只读梦违卡")
 app.query="衍生物";app.update_library();await process_frame
 expect(app.library_ids().size()==16 and app.library_ids().all(func(id):return Store.CARDS[id].token),"搜索衍生物展示全部只读衍生物卡")
 expect(app.library.get_children().all(func(row):return not row.draggable),"衍生物卡库行只能预览")
 expect(not app.valid_drag_source({"card_id":"token-ucs-099","source_zone":"library"}),"衍生物不能从卡库拖入卡组")
 var illegal=Store.blank("只读卡验证");illegal.leader="70"
 expect(not Store.add_card(illegal,"new-eto-002","main").is_empty() and not Store.add_card(illegal,"token-ucs-099","side").is_empty(),"梦违与衍生物均被卡组加入规则拒绝")
 illegal.main.append("token-ucs-099")
 expect("不能加入常规卡组" in Store.validate(illegal),"手工编辑卡组文件也不能绕过衍生物限制")
 print("V11 UI ",checks," checks; failures=",failures)
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
