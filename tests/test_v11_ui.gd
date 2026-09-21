extends "res://tests/test_bugs0921_ui.gd"
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/v11/ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 expect(nodes_of_type(app,"Label").any(func(n):return n.text=="VERSION 1.1"),"主菜单显示1.1")
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
 await capture("v11-okina-editor")
 print("V11 UI ",checks," checks; failures=",failures)
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
