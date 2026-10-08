extends "res://tests/support/ui_base.gd"
var output="res://work/android-popup-capacity"

class RailSession extends RefCounted:
 var room={"undo_request":{}}
 var read_only=false
 var connected=true
 var paused=false
 func ended():return false

func frames(count: int=8):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func swipe(at: Vector2,distance: float):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 for i in range(1,7):
  var motion=InputEventScreenDrag.new();motion.index=0;motion.position=at-Vector2(0,distance*i/6);motion.relative=Vector2(0,-distance/6)
  root.push_input(motion,true);await process_frame
 event=event.duplicate();event.position=at-Vector2(0,distance);event.pressed=false
 root.push_input(event,true);await frames()

func check_popup(panel: Control,label: String):
 expect(panel!=null,label+" opens")
 if panel==null:return
 var bounds=panel.get_global_rect()
 expect(app.ui_metrics.safe.grow(1).encloses(bounds),label+" stays in safe area")
 if panel.get_parent()==view.modal_root:
  expect(not view.observe_button.get_global_rect().intersects(view.android_back_button.get_global_rect()),label+" observation and back controls stay separate")
  for persistent in [view.observe_button,view.android_back_button]:
   expect(not bounds.intersects(persistent.get_global_rect()),label+" leaves persistent controls clear: "+persistent.name)
 for scroll in panel.find_children("*","ScrollContainer",true,false):
  if not scroll.is_visible_in_tree():continue
  var area=scroll.get_global_rect()
  expect(bounds.grow(1).encloses(area),label+" scroll stays inside popup: "+scroll.name)
  expect(area.size.y>=app.ui_metrics.hit,label+" list has a usable height: "+scroll.name)
  var bar=scroll.get_v_scroll_bar()
  scroll.scroll_vertical=roundi(bar.max_value-bar.page);await frames()
  if scroll.get_child_count()>0:
   var content=scroll.get_child(0) as Control
   if content!=null:
    expect(content.get_global_rect().size.x<=area.size.x+1,label+" content fits list width")
    var rows=content.get_children().filter(func(child):return child is Control and child.visible)
    if not rows.is_empty():expect(rows.back().get_global_rect().end.y<=area.end.y+1 and rows.back().get_global_rect().end.y>area.position.y,label+" last list row is reachable")
 for button in panel.find_children("*","Button",true,false):
  if not button.is_visible_in_tree():continue
  expect(button.get_global_rect().position.x>=bounds.position.x-1 and button.get_global_rect().end.x<=bounds.end.x+1,label+" option fits popup width")
  expect(button.size.y>=app.ui_metrics.hit or button.has_meta("capacity_card"),label+" touch target: "+button.text.left(12))
  if button.get_parent() is HBoxContainer and "Footer" in button.get_parent().name:
   expect(bounds.grow(1).encloses(button.get_global_rect()),label+" footer button stays in popup")

func check_right_actions(prefix: String):
 clean(true);view.response_mode=view.ResponseMode.ON
 for i in range(12):
  var card=e.make_card("53",0,"stack")
  e.stack.append({"id":100+i,"kind":"card","card":card,"owner":0,"target":{"none":true},"name":e.cards["53"].name})
 view.render();await settle();view.render();await frames()
 for count in [3,12,40]:
  view.render();await frames()
  var pressed=[]
  for i in range(count):
   var button=view.responsive.button(view.hud,"操作 %02d：选择目标并确认当前能力的额外处理方式" % i,func():pressed.append(i))
   view.responsive.add_phase_action(button)
  view.responsive.position_persistent();await frames()
  var action_scroll=view.hud.find_child("PhaseActionScroll",true,false) as ScrollContainer
  expect(action_scroll!=null,prefix+" %d actions have a bounded scroll viewport" % count)
  if action_scroll==null:continue
  var area=action_scroll.get_global_rect()
  expect(app.ui_metrics.safe.grow(1).encloses(area),prefix+" %d actions stay in safe area" % count)
  expect(area.position.y>=view.OPPONENT_HAND_COUNT.end.y,prefix+" many actions leave opponent hand count clear")
  expect(area.end.y<=view.android_back_button.get_global_rect().position.y-app.ui_metrics.gap+1,prefix+" many actions leave back clear")
  expect(view.stack_panel.visible and not area.intersects(view.stack_panel.get_global_rect()),prefix+" many actions retain a separate stack")
  var stack_scroll=view.stack_panel.scroll
  var minimum_stack_view=maxf(app.ui_metrics.hit,view.stack_panel.ANDROID_CARD_SIZE.y*0.45)
  expect(stack_scroll.size.y>=minimum_stack_view,prefix+" stack shows at least a touch-sized half card")
  var top_tile=view.stack_panel.column.get_child(0).get_child(0) as Control
  var stack_view=stack_scroll.get_global_rect()
  stack_scroll.scroll_vertical=ceili(stack_scroll.scroll_vertical+top_tile.get_global_rect().end.y-stack_view.end.y)+2
  await frames()
  expect(top_tile.get_global_rect().end.y<=stack_view.end.y+1 and top_tile.get_global_rect().end.y>stack_view.position.y,prefix+" stack card bottom is reachable by scrolling")
  stack_scroll.scroll_vertical=0;await frames()
  var bar=action_scroll.get_v_scroll_bar()
  action_scroll.scroll_vertical=roundi(bar.max_value-bar.page);await frames()
  var last=view.responsive.action_column.get_child(view.responsive.action_column.get_child_count()-1)
  expect(area.grow(1).encloses(last.get_global_rect()),prefix+" last of %d actions is reachable" % count)
  await click(last.get_global_rect().get_center())
  expect(pressed==[count-1],prefix+" last action remains clickable")
  if count==40:await shot(prefix+"-40-actions")
  if count==40:
   action_scroll.scroll_vertical=0;await frames()
   await swipe(area.position+Vector2(32,area.size.y-20),maxf(36,area.size.y*0.7))
   expect(action_scroll.scroll_vertical>0,prefix+" crowded right menu supports finger scrolling")
   view.network_session=RailSession.new();view.responsive.position_persistent();await frames()
   area=action_scroll.get_global_rect()
   expect(app.ui_metrics.safe.grow(1).encloses(area) and area.position.y>=view.responsive.network_latency_rect().end.y,prefix+" network latency and crowded actions stay separate")
   expect(view.stack_panel.visible and not view.stack_panel.get_global_rect().intersects(area),prefix+" network stack remains separate from crowded actions")
   action_scroll.scroll_vertical=roundi(bar.max_value-bar.page);await frames()
   expect(area.has_point(last.get_global_rect().get_center()),prefix+" final network action stays reachable")
   await shot(prefix+"-network-40-actions")
   view.network_session=null

func check_palette(prefix: String):
 for who in [0,1]:
  clean(true);view.set_android_camera_focus(who)
  for count in [0,1,0]:
   e.players[who].palette=[]
   if count>0:put("53","palette",who)
   view.render();await frames()
   var toggle=view.hud.find_child("AndroidCameraFocusToggle",true,false) as Button
   expect(view.android_palette_view and view.android_palette_focus_owner()==who,prefix+" palette camera stays focused on the selected owner")
   expect(toggle!=null and toggle.text==("我方颜色盘视角" if who==view.local_seat else "敌方颜色盘视角"),prefix+" palette focus is identified by the camera control")
   expect(not is_instance_valid(view.android_palette_panel),prefix+" palette camera has no obscuring popup")
   expect(e.players[who].palette.size()==count,prefix+" palette cards remain in the selected zone")
  await shot(prefix+"-empty-palette-"+str(who))
 view.set_android_camera_focus(-1)

func check_notices(prefix: String):
 clean(true);view.render();await frames()
 var label=view.txt("选择一个单位作为目标，然后确认该效果的处理顺序。",Rect2(),17,app.GOLD)
 view.responsive.add_choice_notice(label);view.responsive.position_persistent();await frames()
 var scroll=view.responsive.notice_scroll
 var area=scroll.get_global_rect()
 expect(scroll.visible and area.size.y>=app.ui_metrics.hit,prefix+" right prompt has a usable scroll viewport")
 expect(area.position.y>=view.OPPONENT_HAND_COUNT.end.y and not area.intersects(view.responsive.action_scroll.get_global_rect()),prefix+" right prompt leaves hand count and action menu clear")
 scroll.scroll_vertical=roundi(scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page);await frames()
 expect(label.get_global_rect().end.y<=area.end.y+1,prefix+" last prompt line stays reachable")
 var options=[{"mode":"查看目标"},{"mode":"查看效果"}]
 view.choose_options("选择处理方式",options,func(_option):pass);await frames()
 expect(not scroll.visible,prefix+" modal suppresses the duplicated right prompt")
 view.close_overlay()

func check_choices(prefix: String):
 for palette in [false,true]:
  clean(true)
  var source=put("53","field")
  view.android_palette_owner=0 if palette else -1
  var options=[]
  for i in range(60):options.append({"mode":"选项 %02d：选择一个目标，随后处理本次能力，并检查所有额外条件和持续效果" % i})
  e.pending={"kind":"effect_choice","owner":0,"options":options,"trigger":{"effect":"capacity","optional":true,"source":source}}
  view.render();await settle();view.render();await frames()
  await check_popup(view.android_choice_panel,prefix+" 60 long options palette="+str(palette))
  if palette and is_instance_valid(view.android_choice_panel):
   expect(view.android_choice_panel.get_meta("centered",false),prefix+" non-target effects stay centered while palette is open")
  expect(not view.responsive.notice_scroll.visible,prefix+" floating options suppress the duplicated right prompt")
  await shot(prefix+"-options-"+str(palette))
 clean(true);view.android_palette_owner=-1
 var card=put("53","field")
 var actions=[]
 for i in range(24):actions.append({"type":"ability","uid":card.uid,"enabled":true,"label":"行动 %02d：选择一个目标并处理该单位的额外能力，完成后再次检查条件" % i})
 view.render();await settle();view.render();await frames()
 view.render_android_actions(card,actions);await frames()
 await check_popup(view.android_choice_panel,prefix+" 24 unit actions")
 await shot(prefix+"-unit-actions")
 clean(true);view.android_palette_owner=-1
 var refs=[]
 for i in range(30):refs.append(e.ref_target(put("53","hand")))
 e.pending={"kind":"effect_choice","owner":0,"options":[{"selection_id":"capacity-region","selection":[{"pool":refs,"min":1,"max":10,"title":"选择至多十张手牌"}]}],"trigger":{"effect":"capacity","optional":false}}
 view.render();await frames()
 await check_popup(view.android_choice_panel,prefix+" 30 region cards")
 await shot(prefix+"-region-cards")

func check_dialogs(prefix: String):
 clean(true);view.android_palette_owner=-1
 var options=[]
 for i in range(40):options.append({"mode":"处理 %02d：本次处理需要检查目标、颜色、持续时间，以及其他单位产生的额外效果" % i})
 var selected=[]
 view.choose_options("选择处理方式",options,func(option):selected.append(option));await frames()
 await check_popup(view.modal_root.get_child(0),prefix+" generic options")
 var last_option=find_button(view.modal_root,options.back().mode)
 if last_option!=null:await click(last_option.get_global_rect().get_center())
 expect(selected==[options.back()],prefix+" last generic option remains clickable")
 view.close_overlay()
 e.players[0].extra_leaders=[]
 for i in range(10):e.players[0].extra_leaders.append(e.make_card("53",0,"leader",true))
 view.leader_zone_clicked(0);await frames()
 if is_instance_valid(view.modal_root):await check_popup(view.modal_root.get_child(0),prefix+" multiple leaders")
 else:expect(false,prefix+" multiple leaders open")
 view.close_overlay();clean(true)
 var unit=put("53","field")
 var triggers=[]
 for i in range(20):triggers.append({"owner":0,"source":unit,"effect":"capacity","optional":false,"name":e.cards[unit.card_id].name,"ability_text":"触发效果 %d：选择一个目标并依序处理所有持续效果和额外条件。" % i})
 e.pending={"kind":"trigger_order","owner":0,"options":triggers}
 view.trigger_order_menu();await frames()
 await check_popup(view.modal_root.get_child(0),prefix+" 20 trigger order choices")
 await shot(prefix+"-trigger-order")
 view.close_overlay()
 unit.wards=[]
 for i in range(40):unit.wards.append({"amount":i+1,"turn":e.turn,"order":i})
 e.pending={"kind":"ward_order","owner":0,"target":e.ref_target(unit),"incoming":20,"options":range(40)}
 view.ward_order_menu();await frames()
 await check_popup(view.modal_root.get_child(0),prefix+" 40 ward choices")
 await shot(prefix+"-wards")
 view.close_overlay();e.pending={}
 view.settings_menu();await frames()
 expect(is_instance_valid(view.android_battle_menu_root),prefix+" unified battle settings opens")
 if is_instance_valid(view.android_battle_menu_root):
  await check_popup(view.android_battle_menu_root.get_node("AndroidBattleMenu"),prefix+" battle settings")
  expect(view.android_battle_menu_root.find_child("BattleSettingsTab",true,false)!=null,prefix+" settings remains a menu tab")
 view.close_android_battle_menu()
 var blockers=[]
 for i in range(14):blockers.append(e.ref_target(put("53","field")))
 e.combat={"attacker":e.ref_target(unit),"blockers":blockers}
 e.pending={"kind":"damage_assignment","owner":0,"total":20}
 view.damage_dialog();await frames()
 await check_popup(view.modal_root.get_child(0),prefix+" 14 damage targets")
 view.close_overlay()
 clean(true)
 for i in range(15):put("token-fdf-127","field")
 var source=e.players[0].field[0]
 view.execute_action({"type":"ability","uid":source.uid,"enabled":true})
 await frames()
 expect(is_instance_valid(view.modal_root),prefix+" batch quantity opens")
 if is_instance_valid(view.modal_root):await check_popup(view.modal_root.get_child(0),prefix+" batch quantity")
 view.close_overlay();e.pending={}
 view.result_overlay();await frames()
 await check_popup(view.modal_root.get_child(0),prefix+" battle result")
 view.close_overlay()
 clean(true)
 var momiji=e.make_card("character-fdf-101",0,"hand")
 e.enter_field(momiji,0);e.pump_choices();view.render();await settle();view.render();await frames()
 expect(is_instance_valid(view.modal_root) and view.modal_root.get_meta("card_search_topmost",false),prefix+" card name choices open")
 if is_instance_valid(view.modal_root):
  await check_popup(view.modal_root.get_child(0),prefix+" card name search")
  var confirm=view.modal_root.find_child("ConfirmSelection",true,false)
  expect(confirm!=null and not confirm.get_global_rect().intersects(view.android_back_button.get_global_rect()),prefix+" card name confirmation leaves back clear")
  await click(view.observe_button.get_global_rect().get_center());await frames()
  expect(view.observing and not view.modal_root.visible,prefix+" card name choices can be hidden to observe the battlefield")
  await click(view.observe_button.get_global_rect().get_center());await frames()
  expect(not view.observing and view.modal_root.visible,prefix+" observation returns to card name choices")
  await shot(prefix+"-name-search")
 view.close_overlay()

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.load_legacy_test_decks()
 for fixture in [{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(2340,1080),"dpi":420.0},{"size":Vector2i(1280,720),"dpi":320.0}]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames();view=null
  root.size=fixture.size;app.layout_dpi_override=fixture.dpi;app.layout_safe_override=Rect2(60,0,fixture.size.x-84,fixture.size.y-24)
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  var prefix="%dx%d-dpi%d" % [fixture.size.x,fixture.size.y,int(fixture.dpi)]
  await check_right_actions(prefix);await check_palette(prefix);await check_notices(prefix);await check_choices(prefix);await check_dialogs(prefix)
 print("ANDROID POPUP CAPACITY: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
