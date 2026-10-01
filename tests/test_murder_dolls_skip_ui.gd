extends "res://tests/support/ui_base.gd"

func action_tile(node: Node,kind: String):
 if node==null:return null
 if node.get_meta("action_type","")==kind:return node
 for child in node.get_children():
  var found=action_tile(child,kind)
  if found:return found
 return null

func tap(at: Vector2):
 if not app.is_android:
  await click(at);return
 var event=InputEventScreenTouch.new();event.position=at;event.index=0;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await process_frame;await physics_frame

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/murder-dolls-ui/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900);root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.is_android=OS.get_cmdline_user_args().has("--android")
 if app.is_android:root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.refresh_ui_metrics();app.load_test_decks();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine
 app.set_show_card_inspection(true);clean()
 var dolls=put("spell-fdf-017","field");dolls.timer=2
 var enemy=put("spell-fdf-017","field",1);enemy.timer=2
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down);view.render();await settle()
  await tap(point(dolls.uid));await settle()
  var tile=action_tile(view.android_choice_panel if app.is_android else view.modal_root,"murder_dolls_skip")
  expect(view.action_menu_open and tile!=null,"点击杀人玩偶提供空场开关：俯视="+str(top_down))
  expect(view.inspection_text.get_parsed_text().begins_with("空场自动跳过：已开启"),"详情显示默认开启及空场条件")
  if tile:await tap(tile.get_global_rect().get_center())
  expect(dolls.get("murder_dolls_skip_disabled",false) and not view.action_menu_open and not view.modal and view.local.is_empty(),"点击关闭直接生效并关闭菜单，无目标或付款操作")
  expect(view.inspection_text.get_parsed_text().begins_with("空场自动跳过：已关闭"),"关闭后详情即时刷新")
  await settle();await tap(point(dolls.uid));await settle()
  tile=action_tile(view.android_choice_panel if app.is_android else view.modal_root,"murder_dolls_skip")
  if tile:await tap(tile.get_global_rect().get_center())
  expect(not dolls.get("murder_dolls_skip_disabled",false) and e.stack.is_empty() and not dolls.tapped,"第二次点击重新开启，不进入对抗或横置")
  if app.is_android:await click(find_button(view.inspection,"关闭详情").get_global_rect().get_center())
  await settle();await tap(point(enemy.uid))
  expect(not view.action_menu_open and view.inspect_uid==enemy.uid,"对手杀人玩偶可查看状态且不提供开关")
  if app.is_android:await click(find_button(view.inspection,"关闭详情").get_global_rect().get_center())
 view.close_overlay();e.stack.append({"id":e.next_stack,"kind":"ability","owner":1,"source":enemy.duplicate(true),"target":{},"name":"测试对抗","amount":0});e.next_stack+=1
 view.set_response_mode(view.ResponseMode.ON);view.render();await settle()
 await tap(point(dolls.uid));await settle()
 var disabled=e.available_actions(0,dolls.uid,true).filter(func(a):return a.type=="murder_dolls_skip")
 expect(disabled.size()==1 and not disabled[0].enabled,"对抗中开关动作禁用")
 var blocked_tile=action_tile(view.android_choice_panel if app.is_android else view.modal_root,"murder_dolls_skip")
 expect(blocked_tile!=null,"对抗中保留禁用的开关菜单")
 if blocked_tile:await tap(blocked_tile.get_global_rect().get_center())
 expect(not dolls.get("murder_dolls_skip_disabled",false) and e.stack.size()==1,"点击禁用开关不会改变状态")
 view.close_overlay();e.stack.clear();e.move_to(dolls,"hand");e.presentation_events.clear();view.render()
 expect(not view.card_context_caption(dolls).contains("空场自动跳过"),"场外不显示生效中的开关状态")
 print("MURDER_DOLLS_SKIP_UI: android=",app.is_android,"; ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
