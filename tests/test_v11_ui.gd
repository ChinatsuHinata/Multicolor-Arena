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
 clean(true)
 var trains=[]
 for i in range(8):trains.append(put("new-spx-007","field"))
 view.render();await settle();await physics_frame
 for wide in [false,true]:
  view.table.wide_playmat=wide
  for top_down in [false,true]:
   view.table.top_down_view=top_down
   var placements=view.table.layout().values().filter(func(d):return d.card_id=="new-spx-007")
   var bounds=view.table.support_bounds()
   var clear=placements.size()==trains.size()
   for i in range(placements.size()):
    var d=placements[i];var half=Vector2(view.table.CARD_SIZE.y,view.table.CARD_SIZE.x)*d.scale.x*0.5
    var center=Vector2(absf(d.at.x),absf(d.at.z))
    var box=Rect2(center-half,half*2)
    clear=clear and bounds.encloses(box) and d.get("copy_index",0)==i+1 and d.get("copy_total",0)==trains.size()
    for j in range(i):
     var other=placements[j];var other_half=Vector2(view.table.CARD_SIZE.y,view.table.CARD_SIZE.x)*other.scale.x*0.5
     var other_box=Rect2(Vector2(absf(other.at.x),absf(other.at.z))-other_half,other_half*2)
     clear=clear and not box.intersects(other_box)
   expect(clear,"八张列车在%s%s视图均可区分且位于结界区" % ["宽" if wide else "标准","俯视" if top_down else "透视"])
 view.table.wide_playmat=false;view.table.top_down_view=false;view.render();await settle();await physics_frame
 var train_displays=view.table.descriptors.values().filter(func(d):return d.card_id=="new-spx-007")
 expect(train_displays.size()==8 and train_displays.all(func(d):return view.card_badges.has(d.key) and view.card_badges[d.key].has("copy_number") and view.card_badges[d.key].copy_number.text=="%d/8" % d.copy_index),"每张列车显示独立序号")
 expect(train_displays.all(func(d):return view.table.card_at(view.table.camera.unproject_position(view.table.visuals[d.key].global_position))==d.uid),"每张列车中心可独立点选")
 await capture("v11-train-layout")
 for i in range(12):put("new-spx-007","field")
 view.render();await settle();await physics_frame
 train_displays=view.table.descriptors.values().filter(func(d):return d.card_id=="new-spx-007")
 expect(train_displays.size()==20 and train_displays.all(func(d):return d.get("fanned",false) and view.card_badges[d.key].copy_number.text==str(d.copy_index)),"二十张列车扇形排列并显示独立编号")
 expect(train_displays.all(func(d):return view.table.card_at(view.table.camera.unproject_position(view.table.visuals[d.key].to_global(Vector3(0,0,-view.table.CARD_SIZE.y*0.43))))==d.uid),"密集列车保留逐张可点选的外露边缘")
 clean(true)
 var batch_graves=[put("53","grave"),put("52","grave"),put("50","grave",1),put("51","grave",1)]
 var batch_fuji=put("character-fdn-043","field")
 view.begin_action(e.extra_action(batch_fuji));await settle()
 expect(view.modal and view.region_batch_group().get("max",0)==3 and view.region_tiles.size()==4,"富士见之女在同一窗口提供至多三张墓地牌")
 var before_batch=snapshot()
 for i in [0,1,2]:
  await click(view.region_tiles[batch_graves[i].uid].get_global_rect().get_center())
 var batch_button=view.modal_root.find_child("RegionConfirm",true,false)
 var batch_count=view.modal_root.find_child("RegionCount",true,false)
 expect(view.region_batch.size()==3 and batch_button.text=="确认选择（3）" and "已选 3 / 最多 3" in batch_count.text and snapshot()==before_batch,"三张目标在确认前可一次勾选且不改变对局")
 await click(view.region_tiles[batch_graves[3].uid].get_global_rect().get_center())
 expect(view.region_batch.size()==3,"超过三张时不追加目标")
 await click(batch_button.get_global_rect().get_center());await settle()
 expect(view.picker.ready() and view.picker.option().picks[0].size()==3 and not view.modal,"一次确认提交整组三张目标")
 view.confirm_declaration();await settle()
 expect(e.stack.size()==1 and e.stack.back().target.picks[0].size()==3,"发动能力保留三张独立目标")
 resolve();view.render();await settle()
 expect(batch_graves.slice(0,3).all(func(c):return c.zone=="exile") and batch_graves[3].zone=="grave","结算只移除选中的三张牌")
 clean(true)
 var own_grave=put("53","grave")
 var other_grave=put("52","grave")
 var enemy_grave_a=put("50","grave",1)
 var enemy_grave_b=put("51","grave",1)
 var eiki=put("35","field")
 var fuji=put("character-fdn-043","field",1)
 e.priority=1
 var grave_refs=[e.Pack.ref(e,own_grave),e.Pack.ref(e,enemy_grave_a),e.Pack.ref(e,enemy_grave_b)]
 expect(e.commit_extension(1,fuji.uid,{"selection_id":"character-fdn-043","picks":[grave_refs]},[],"character-fdn-043").is_empty(),"富士见之女指向双方墓地三张牌")
 e.presentation_events.clear();view.reveal_player.reset();view.render();await settle()
 expect(view.grave_target_tiles.size()==3 and view.stack_target_arrows().size()==3,"墓地目标逐张显示并有独立箭头")
 expect(not view.target_rect(grave_refs[1]).intersects(view.target_rect(grave_refs[2])),"同一墓地的两张目标牌可区分")
 view.begin_action(e.extra_action(eiki));await process_frame
 expect(not view.modal and view.grave_target_tiles.size()==3,"映姬响应时独立目标保持可点击")
 var other_button=find_button(view.grave_target_layer,"选择其他墓地牌")
 expect(other_button!=null,"仍可浏览未被堆叠指向的墓地牌")
 if other_button!=null:
  await click(other_button.get_global_rect().get_center())
  expect(view.modal and view.region_tiles.has(other_grave.uid),"其他墓地牌可在选择器中精确选取")
  view.close_overlay()
 await click(view.grave_target_tiles[enemy_grave_a.uid].get_global_rect().get_center())
 expect(view.local.get("target",{}).get("uid",-1)==enemy_grave_a.uid,"点击指定墓地牌选中精确目标")
 view.confirm_declaration();await process_frame
 expect(e.stack.size()==2 and e.stack.back().target.get("uid",-1)==enemy_grave_a.uid,"映姬在富士见之女上方响应")
 e.pass_priority(e.priority);e.pass_priority(e.priority);view.render();await settle()
 expect(enemy_grave_a.zone=="exile" and own_grave.zone=="grave" and enemy_grave_b.zone=="grave","映姬先移除指定目标")
 expect(view.grave_target_tiles.size()==2 and not view.grave_target_tiles.has(enemy_grave_a.uid),"离开墓地的目标不再显示")
 e.pass_priority(e.priority);e.pass_priority(e.priority);view.render();await settle()
 expect(own_grave.zone=="exile" and enemy_grave_b.zone=="exile" and other_grave.zone=="grave" and view.grave_target_tiles.is_empty(),"原能力继续处理有效目标并清理显示")
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
