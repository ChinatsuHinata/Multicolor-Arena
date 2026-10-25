extends "res://tests/support/ui_base.gd"

func frames(count: int=4):
 for i in range(count):await process_frame

func confirmation():
 for child in app.get_children():
  if child is ConfirmationDialog and child.visible:return child
 return null

func tap(button: Button):
 if button==null:return
 if not app.is_android:
  await click(button.get_global_rect().get_center());await frames();return
 var event=InputEventScreenTouch.new();event.index=0;event.position=button.get_global_rect().get_center();event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func prepare(from_zone: String,destination: String):
 clean(true)
 var leader=e.players[0].leader
 e.shift(leader,from_zone);e.players[0][from_zone].append(leader)
 e.move_to(leader,destination);e.pump_choices()
 e.presentation_events.clear();view.reveal_player.reset();view.render();await frames()
 expect(e.pending.get("kind","")=="leader_return","实际区域移动提供自机返回选择："+from_zone+" → "+destination)
 check_popup(("安卓" if app.is_android else "桌面")+" "+from_zone+" → "+destination)
 return leader

func check_popup(label: String):
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel),label+" 自动弹出自机去向选择")
 if not is_instance_valid(panel):return
 expect(panel.get_meta("centered",false) and panel.get_global_rect().get_center().distance_to(app.get_viewport_rect().get_center())<1,label+" 去向弹窗位于屏幕中央")
 expect(app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()),label+" 弹窗位于安全区域内")
 var notice=panel.find_child("LeaderReturnPrompt",true,false)
 expect(notice!=null and notice.text.contains(e.cards[e.pending.card.card_id].name),label+" 弹窗指出正在移动的自机")
 if notice!=null:
  var height=notice.get_theme_font("font").get_multiline_string_size(notice.text,HORIZONTAL_ALIGNMENT_LEFT,notice.size.x,notice.get_theme_font_size("font_size")).y
  expect(notice.get_theme_font_size("font_size")==app.ui_metrics.body and notice.size.y>=height,label+" 说明按正文字号完整换行")
 var choices=panel.find_child("LeaderReturnChoices",true,false)
 expect(choices!=null and choices.get_child_count()==2,label+" 两个去向均在弹窗内")
 if choices==null:return
 for button in choices.get_children():
  expect(panel.get_global_rect().encloses(button.get_global_rect()) and button.size.y>=app.ui_metrics.hit,label+" 去向按钮在弹窗内且可触控："+button.text)
  expect(not view.responsive.action_column.is_ancestor_of(button),label+" 去向按钮不再位于右下操作栏")

func return_button():
 var button=find_button(view.ui,"返回自机区")
 expect(button!=null,"显示返回自机区操作")
 return button

func check_surface(android: bool):
 app.is_android=android;app.refresh_ui_metrics();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine
 var label="安卓" if android else "桌面"
 var hidden=await prepare("field","hand");var hidden_before=snapshot()
 await capture("leader-return-"+("android" if android else "desktop"))
 await tap(find_button(view.android_choice_panel,"隐藏"))
 expect(not is_instance_valid(view.android_choice_panel) and is_instance_valid(view.android_choice_restore) and snapshot()==hidden_before,label+" 隐藏弹窗保留待选去向")
 await tap(view.android_choice_restore)
 check_popup(label+" 重新展开")
 expect(hidden.zone=="return_pending" and snapshot()==hidden_before,label+" 展开弹窗不会提交去向")
 for move in [["field","hand"],["field","deck"],["field","exile"],["field","palette"],["hand","palette"],["hand","deck"],["hand","grave"],["hand","exile"],["palette","hand"],["palette","grave"],["deck","hand"],["deck","palette"]]:
  var leader=await prepare(move[0],move[1]);var before=snapshot()
  await tap(return_button())
  var dialog=confirmation()
  expect(dialog!=null and snapshot()==before,label+" 非死亡返回先确认且尚未移动："+str(move))
  if dialog==null:continue
  expect(dialog.dialog_text.contains(e.cards[leader.card_id].name),label+" 确认提示指出当前自机")
  dialog.canceled.emit();await frames()
  expect(confirmation()==null and snapshot()==before,label+" 取消确认保留原去向选择")
  await tap(return_button());dialog=confirmation()
  if dialog:dialog.confirmed.emit();await frames()
  expect(leader.zone=="leader" and leader.timer==2 and e.pending.is_empty(),label+" 二次确认后实际返回自机区并获得计时")

 for home in [false,true]:
  clean(true);var leader=e.players[0].leader
  e.move_to(leader,"hand",false);var color=put("164","palette")
  e.phase="possession";e.pending={"kind":"possession","owner":0}
  e.presentation_events.clear();view.reveal_player.reset()
  view.selection=[color.uid,leader.uid];view.render();await frames()
  await tap(find_button(view.ui,"确定凭依"))
  expect(e.pending.get("kind","")=="leader_return" and color.zone=="hand",label+" 真实凭依显示手牌自机进入颜色盘的去向选择")
  e.presentation_events.clear();view.reveal_player.reset();view.render();await frames()
  check_popup(label+" 凭依移动")
  if home:
   await tap(return_button());var dialog=confirmation()
   expect(dialog!=null,label+" 凭依返回自机区也要求二次确认")
   if dialog:dialog.confirmed.emit();await frames()
  else:await tap(find_button(view.ui,"放入颜色盘"))
  expect(leader.zone==("leader" if home else "palette") and e.pending.is_empty(),label+" 凭依界面的两种去向均能实际完成")

 var dead=await prepare("field","grave")
 await tap(return_button())
 expect(confirmation()==null and dead.zone=="leader" and dead.timer==2,label+" 死亡返回沿用一次选择")

 var staying=await prepare("field","hand")
 await tap(return_button());var dialog=confirmation()
 if dialog:dialog.canceled.emit();await frames()
 await tap(find_button(view.ui,"移回手牌"))
 expect(confirmation()==null and staying.zone=="hand" and e.players[0].hand.has(staying),label+" 取消返回后仍可直接选择原去向")

 var first=await prepare("field","hand")
 var old_destination=find_button(view.android_choice_panel,"移回手牌").pressed
 var old_return=return_button().pressed
 await tap(return_button());dialog=confirmation()
 e.choose_return(false)
 var second=e.players[1].leader
 e.shift(second,"field");e.players[1].field.append(second)
 e.move_to(second,"exile");e.pump_choices()
 var before=snapshot()
 if dialog:dialog.confirmed.emit();await frames()
 expect(first.zone=="hand" and second.zone=="return_pending" and snapshot()==before,label+" 过期确认不会处理下一张自机")
 old_destination.emit();await frames()
 expect(snapshot()==before,label+" 过期去向按钮不会处理下一张自机")
 old_return.emit();await frames()
 expect(confirmation()==null and snapshot()==before,label+" 过期返回按钮不会为下一张自机打开确认")
 e.presentation_events.clear();view.reveal_player.reset();view.render();await frames()
 check_popup(label+" 下一张自机")
 if is_instance_valid(view.android_choice_panel):await tap(find_button(view.android_choice_panel,"移除游戏"))
 expect(second.zone=="exile" and e.pending.is_empty(),label+" 连续移动的下一张自机可在新弹窗提交去向")

func check_small_android():
 root.size=Vector2i(1280,720);app.is_android=true;app.layout_dpi_override=320.0
 app.layout_safe_override=Rect2(60,0,1196,696)
 await frames();app.refresh_responsive_layout();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine
 await prepare("hand","palette")
 await capture("leader-return-android-small")
 await tap(find_button(view.android_choice_panel,"放入颜色盘"))
 expect(e.players[0].leader.zone=="palette" and e.pending.is_empty(),"安卓小屏安全区域内可以点按弹窗完成移动")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/leader-return-ui/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900);root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();app.tutorial_local_directory=Store.Paths.root_override.path_join("tutorials")
 root.add_child(app);await frames()
 app.load_legacy_test_decks()
 await check_surface(false);await check_surface(true);await check_small_android()
 print("LEADER_RETURN_UI: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
