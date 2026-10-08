extends "res://tests/support/ui_base.gd"
## Check visible geometry and input with the popup and a populated stack together.
var output="res://work/battle-choice-overlap"

func frames(count: int=8):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func visible_buttons(node: Node) -> Array:
 var result=[]
 if node is Button and node.is_visible_in_tree():result.append(node)
 for child in node.get_children():result.append_array(visible_buttons(child))
 return result

func check_button_clear(button: Button,label: String):
 var rect=button.get_global_rect()
 expect(app.ui_metrics.safe.grow(1).encloses(rect),label+" stays in the safe area")
 for other in [view.android_back_button,view.hud.find_child("BattleTools",true,false)]:
  if is_instance_valid(other) and other.is_visible_in_tree():expect(not rect.intersects(other.get_global_rect()),label+" leaves "+str(other.name)+" clear")
 for other in visible_buttons(view.responsive.action_column):
  expect(not rect.intersects(other.get_global_rect()),label+" leaves the lower action clear: "+other.text)
 if view.stack_panel.is_visible_in_tree():
  expect(not rect.intersects(view.stack_panel.get_global_rect()),label+" leaves the visible stack panel clear")
  var toggle=view.stack_panel.toggle_button
  if is_instance_valid(toggle) and toggle.is_visible_in_tree():expect(not rect.intersects(toggle.get_global_rect()),label+" leaves the external stack toggle clear")
  for id in view.stack_panel.tiles:expect(not rect.intersects(view.stack_panel.entry_rect(id)),label+" leaves stack card %s clear" % id)

func stack_fixture():
 for i in range(6):
  var card=e.make_card("53",0,"stack")
  e.stack.append({"id":100+i,"kind":"card","card":card,"owner":0,"target":{"none":true},"name":e.cards["53"].name})

func check_state(prefix: String,actions: bool):
 clean();view.response_mode=view.ResponseMode.ON
 stack_fixture()
 if actions:
  e.cards["53"]=e.cards["53"].duplicate(true)
  e.cards["53"].abilities.append({"实现":"activated_damage","名称":"启动能力","参数":{"数值":1,"费用":{},"横置":false}})
  var unit=put("53","field")
  view.render();await frames();view.open_actions(unit)
 else:
  var source=put("character-fdn-068","field")
  e.pending={"kind":"effect_choice","owner":0,"options":[{"color":"红"},{"color":"蓝"},{"color":"绿"},{"color":"黄"},{"color":"黑"}],"trigger":{"effect":"lily_color","optional":false,"source":source}}
  view.render()
 await frames()
 var label=prefix+(" action" if actions else " effect")
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel),label+" popup opens with six stack entries")
 if not is_instance_valid(panel):return
 var hide=find_button(panel,"隐藏")
 expect(panel.get_global_rect().grow(1).encloses(hide.get_global_rect()),label+" hide is inside the popup")
 check_button_clear(hide,label+" hide")
 var confirm=find_button(panel,"确定")
 if confirm!=null:expect(not hide.get_global_rect().intersects(confirm.get_global_rect()),label+" hide and confirm do not overlap")
 expect(view.stack_panel.is_visible_in_tree() and not panel.get_global_rect().intersects(view.stack_panel.get_global_rect()),label+" centered ability popup leaves the stack visible and clear")
 if view.is_android:
  var toggle=view.stack_panel.toggle_button
  expect(is_instance_valid(toggle) and toggle.is_visible_in_tree() and not panel.get_global_rect().intersects(toggle.get_global_rect()),label+" entire popup clears the external stack toggle")
  for choice in visible_buttons(panel):
   expect(not choice.get_global_rect().intersects(toggle.get_global_rect()),label+" popup action clears the stack toggle: "+choice.text)
  if not actions:
   var before_toggle=snapshot()
   view.stack_panel.set_collapsed(true);view.render();await frames()
   panel=view.android_choice_panel;hide=find_button(panel,"隐藏")
   expect(view.stack_panel.collapsed and is_instance_valid(panel),label+" popup can open while the stack is folded")
   view.stack_panel.set_collapsed(false);await frames()
   expect(not panel.get_global_rect().intersects(view.stack_panel.toggle_button.get_global_rect()) and snapshot()==before_toggle,label+" reopening the stack leaves the existing popup clear without changing duel state")
 var before=snapshot()
 await click(hide.get_global_rect().get_center());await frames()
 expect(snapshot()==before and view.android_choice_panel==null,label+" hide click only collapses the popup")
 var restore=view.android_choice_restore
 expect(is_instance_valid(restore),label+" expand control is available")
 if not is_instance_valid(restore):return
 check_button_clear(restore,label+" expand")
 expect(view.stack_panel.is_visible_in_tree(),label+" hidden popup exposes the stack")
 expect(view.stack_panel.scroll.size.y>=180 if view.is_android else view.stack_panel.scroll.size.y>=view.stack_panel.CARD_SIZE.y,label+" hidden popup leaves a readable, scrollable stack area")
 if view.stack_panel.is_visible_in_tree():
  var bar=view.stack_panel.scroll.get_v_scroll_bar()
  view.stack_panel.scroll.scroll_vertical=roundi(bar.max_value-bar.page);await frames()
  expect(view.stack_panel.entry_rect(100).has_area(),label+" final stack card remains reachable")
  if view.is_android:expect(not view.stack_panel.get_global_rect().intersects(view.android_back_button.get_global_rect()),label+" hidden stack leaves the lower back button clear")
 if actions and not view.is_android or prefix.begins_with("1280x720"):
  await create_timer(1.5).timeout
  await shot(label.replace(" ","-")+"-hidden")
 var menu=view.hud.find_child("BattleTools",true,false) as Button
 await click(menu.get_global_rect().get_center());await frames()
 if view.is_android:
  expect(is_instance_valid(view.android_battle_menu_root) and snapshot()==before,label+" unified menu preserves a hidden choice")
  view.close_android_battle_menu();await frames()
 else:
  expect(app.menu_popup_open() and snapshot()==before,label+" menu remains clickable after hiding")
  app.close_menu_popup();await frames()
 await click(restore.get_global_rect().get_center());await frames()
 expect(is_instance_valid(view.android_choice_panel) and snapshot()==before,label+" expand restores the popup without submitting an action")
 check_button_clear(find_button(view.android_choice_panel,"隐藏"),label+" restored hide")
 if actions:
  await click(find_button(view.android_choice_panel,"隐藏").get_global_rect().get_center());await frames()
  var response=find_button(view.responsive.action_column,"不响应 / 继续")
  expect(response!=null and response.is_visible_in_tree(),label+" lower response action remains available")
  if response!=null:
   var revision=e.revision
   await click(response.get_global_rect().get_center());await frames()
   expect(e.revision==revision+1 and e.priority==1,label+" lower response action receives the click once")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 var cases=[{"size":Vector2i(1600,900),"dpi":0.0},{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(1920,1080),"dpi":360.0},{"size":Vector2i(2340,1080),"dpi":420.0},{"size":Vector2i(2160,1080),"dpi":480.0},{"size":Vector2i(1280,720),"dpi":320.0}]
 for fixture in cases:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=fixture.size;app.is_android=fixture.dpi>0;app.layout_dpi_override=fixture.dpi
  app.layout_safe_override=Rect2(60,0,fixture.size.x-84,fixture.size.y-24) if app.is_android else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  var prefix="%dx%d-dpi%d" % [fixture.size.x,fixture.size.y,int(fixture.dpi)]
  await check_state(prefix,false);await check_state(prefix,true)
 print("BATTLE CHOICE OVERLAP: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
