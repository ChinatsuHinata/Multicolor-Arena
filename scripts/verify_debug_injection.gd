extends SceneTree

const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var failures=[]
var checks=0
const OUTPUT="res://work/debug-tools-tests"

func check(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)

func _initialize():call_deferred("run")

func find_control(node: Node,kind: String):
 if node.get_class()==kind:return node
 for child in node.get_children():
  var found=find_control(child,kind)
  if found!=null:return found
 return null

func find_button(node: Node,title: String):
 if node is Button and node.text==title:return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found!=null:return found
 return null

func pick_card(view,id: String) -> bool:
 var search=view.modal_root.find_child("SearchInput",true,false)
 if search==null:return false
 search.text=id;search.text_changed.emit(id)
 var results=view.modal_root.find_child("SearchResults",true,false)
 if results==null:return false
 for row in results.get_children():
  if row is Button and row.get_meta("card_id","")==id:
   row.pressed.emit()
   var confirm=view.modal_root.find_child("ConfirmSelection",true,false)
   if not confirm is Button or confirm.disabled:return false
   confirm.pressed.emit()
   return true
 return false

func frames(count: int=5):
 for i in range(count):await process_frame

func quiet(view):
 for i in range(240):
  await process_frame
  if not view.revealing() and not view.table.is_animating():return
  await create_timer(0.015).timeout
 check(false,"debug presentation finishes before input")

func key(code: int,options: Dictionary={}):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true
 for name in options:event.set(name,options[name])
 root.push_input(event,true);await frames(2)
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames(2)

func click(at: Vector2,button: int=MOUSE_BUTTON_LEFT):
 var event=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=button;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func engine_copy_checks(e):
 var events=e.presentation_events.duplicate(true)
 for who in range(2):
  for zone in ["deck","hand","field","palette","grave","exile","leader"]:
   var original=e.players[who].leader if zone=="leader" else e.make_card("new-eto-008" if zone in ["grave","exile"] else "53",who,zone)
   if zone!="leader":e.players[who][zone].append(original)
   original.tapped=true;original.damage=2;original.timer=3;original.plus_counters=4;original.color_counters=["红","蓝"]
   var uid=e.debug_copy(original.uid);var copy=e.find_card(uid)
   check(uid>0 and uid!=original.uid and copy.get("owner")==who and copy.get("zone")==zone and copy.get("card_id")==original.card_id,"copy retains card, owner and zone: "+zone+str(who))
   check(copy.get("tapped",false) and copy.get("damage")==2 and copy.get("timer")==3 and copy.get("plus_counters")==4 and copy.get("color_counters")==["红","蓝"],"copy retains tutorial tableau state: "+zone+str(who))
   if zone!="leader":
    var cards=e.players[who][zone]
    check(cards.find(copy)==cards.find(original)+1,"copy follows the original instance: "+zone+str(who))
   copy.color_counters.append("绿")
   check(original.color_counters==["红","蓝"],"copy counter arrays are independent: "+zone+str(who))
 check(e.stack.is_empty() and e.pending.is_empty() and e.triggers.is_empty() and e.presentation_events==events,"debug copying dispatches no rule or presentation events")
 var uid=e.players[0].leader.uid;var next=e.next_uid
 e.debug_enabled=false;check(e.debug_copy(uid)==0,"copy requires debug mode");e.debug_enabled=true
 e.pending={"kind":"test"};check(e.debug_copy(uid)==0,"copy waits for pending choices");e.pending={}
 e.stack=[{"kind":"ability"}];check(e.debug_copy(uid)==0,"copy waits for the stack");e.stack=[]
 e.combat={"attacker":{}};check(e.debug_copy(uid)==0,"copy waits for combat");e.combat={}
 e.winner=0;check(e.debug_copy(uid)==0,"copy stops after the duel ends");e.winner=-2
 check(e.debug_copy(-100)==0 and e.next_uid==next,"rejected copies create no instances")

func visible_buttons(node: Node) -> Array:
 var result=[]
 if node is BaseButton and node.is_visible_in_tree():result.append(node)
 for child in node.get_children():result.append_array(visible_buttons(child))
 return result

func ui_copy_checks(view):
 var game=view.engine
 for who in range(2):
  for zone in ["deck","hand","field","palette","grave","exile","leader"]:
   await quiet(view)
   var source=game.players[who].leader if zone=="leader" else game.make_card("new-eto-008" if zone in ["grave","exile"] else "53",who,zone)
   if zone!="leader":game.players[who][zone].append(source)
   source.plus_counters=2
   view.browse_zone(who,zone);await frames();await quiet(view)
   var art
   for row in view.browser_cards.get_children():
    var candidate=row.get_node("PileCard")
    if candidate.get_meta("browser_uid")==source.uid:art=candidate;break
   view.browser_scroll.ensure_control_visible(art);await frames()
   await click(art.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
   check(view.inspect_uid==source.uid,"right click selects a copy source: "+zone+str(who))
   var next=game.next_uid;await key(KEY_C);await quiet(view)
   var copy=game.find_card(next)
   check(copy.get("card_id")==source.card_id and copy.get("owner")==who and copy.get("zone")==zone and copy.get("plus_counters")==2,"real C input copies the inspected region card: "+zone+str(who))
   check(view.debug_open and view.browser_owner==who and view.browser_zone==zone and view.inspect_uid==next,"copy keeps the region browser and inspects the new instance: "+zone+str(who))
  print("DEBUG_COPY_UI: all regions checked for player "+str(who))
 var before=game.next_uid
 for kind in [LineEdit,TextEdit]:
  var input=kind.new();view.add_child(input);input.grab_focus();await frames();await key(KEY_C)
  check(game.next_uid==before and not view.modal,"text entry cannot copy or open graveyard injection")
  input.free();await frames()
 await key(KEY_C,{"ctrl_pressed":true});await key(KEY_C,{"echo":true})
 check(game.next_uid==before,"modified and repeated C do not copy")
 game.stack=[{"id":1,"kind":"ability","owner":0,"source":game.players[0].leader,"name":"测试能力","target":{"none":true}}];await key(KEY_C)
 check(game.next_uid==before,"real C input cannot copy during a stack");game.stack=[]
 view.close_debug();view.inspect_id="";view.inspect_uid=0;view.render();await quiet(view);await key(KEY_C)
 check(not view.modal and game.next_uid==before,"C without a copy source never opens a graveyard picker")
 for dimensions in [Vector2i(1600,900),Vector2i(1280,720)]:
  root.size=dimensions;await frames();view.render();await frames()
  var toggle=view.debug_free_checkbox
  check(root.get_visible_rect().encloses(toggle.get_global_rect()),"free payment fits the viewport: "+str(dimensions))
  var clear=true
  for button in visible_buttons(view):
   if button!=toggle and toggle.get_global_rect().intersects(button.get_global_rect()):
    clear=false;print("DEBUG_LAYOUT_OVERLAP: "+button.text+" "+str(button.get_global_rect()))
  check(clear,"free payment avoids every other visible button: "+str(dimensions))
  var enabled=game.debug_free_payment;await click(toggle.get_global_rect().get_center())
  check(game.debug_free_payment!=enabled and view.host.debug_free_payment==game.debug_free_payment,"free payment receives clicks without invoking another action")
  var keep=view.hud.get_node("AutoPayKeepButton")
  await click(keep.get_global_rect().get_center())
  check(view.keep_popup_open and is_instance_valid(view.keep_popup) and not view.keep_popup.get_global_rect().intersects(toggle.get_global_rect()),"retained-color button and popup stay usable beside free payment")
  keep=view.hud.get_node("AutoPayKeepButton")
  await click(keep.get_global_rect().get_center())
  view.host.auto_pay_keep_colors=["红","蓝","绿","黄","黑"];view.render();await frames()
  keep=view.hud.get_node("AutoPayKeepButton")
  var text_width=keep.get_theme_font("font").get_string_size(keep.text,HORIZONTAL_ALIGNMENT_LEFT,-1,keep.get_theme_font_size("font_size")).x
  check(text_width<=keep.size.x-keep.get_theme_stylebox("normal").get_minimum_size().x and not keep.get_global_rect().intersects(toggle.get_global_rect()),"all retained colors fit the compact debug row without overlap")
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUTPUT.path_join("debug-"+str(dimensions.x)+".png"))

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 Store.Paths.root_override=ProjectSettings.globalize_path(OUTPUT.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var deck=Store.blank("debug tools");deck.leader="70"
 for i in range(50):deck.main.append("164")
 var e=Duel.new();e.start(deck,deck,0,5)
 for p in e.players:
  p.hand=[];p.field=[];p.palette=[];p.grave=[];p.mulligan_done=true;p.potato=false
 e.phase="main";e.active=0;e.priority=0
 check(e.debug_add("53",1,"field")!="","new cards require test mode")
 e.debug_enabled=true
 check(e.debug_add("new-eto-002",1,"field")=="" and e.players[1].field.back().card_id=="new-eto-002","dream unit added to selected side")
 check(e.pending.is_empty() and e.stack.is_empty(),"injection does not trigger entry effects")
 check(e.debug_add("token-fdf-127",0,"field")=="" and e.players[0].field.back().token,"printed token can be added")
 check(e.debug_add("field-fdf-089",1,"field")=="","enchantment can be added")
 check(e.debug_add("new-eto-008",0,"grave")=="" and e.players[0].grave.back().card_id=="new-eto-008","dream card can be placed in graveyard")
 check(e.debug_add("53",0,"palette")=="" and not e.players[0].palette.back().tapped,"palette injection is upright")
 check(e.debug_add("53",0,"hand")=="","hand injection succeeds")
 var unit=e.players[0].hand.back()
 e.players[0].palette.back().tapped=true
 check(e.cast_error(0,unit.uid)=="可用颜色费用不足","normal payment remains required")
 e.debug_free_payment=true
 check(e.cast_error(0,unit.uid)=="" and e.payment(0,e.cast_cost(0,unit)).plan.is_empty(),"free payment permits casting with no colors")
 check(e.commit_cast(0,unit.uid,{},[]).is_empty(),"free cast commits with an empty payment plan")
 var copy_game=Duel.new();copy_game.start(deck,deck,0,5);copy_game.debug_enabled=true
 copy_game.phase="main";copy_game.pending={};copy_game.stack=[];copy_game.combat={}
 engine_copy_checks(copy_game)
 print("DEBUG_COPY: engine checks complete")
 var app=load("res://main.tscn").instantiate();app.settings_path=OUTPUT.path_join("settings.json");app.account_session_path=OUTPUT.path_join("account.json");root.add_child(app);await process_frame
 app.setup()
 var test_switch=find_button(app,"测试模式（手动控制双方）")
 check(test_switch!=null and not test_switch.button_pressed,"human versus AI setup exposes test mode")
 test_switch.button_pressed=true
 check(app.debug_mode,"setup enables test mode without a password")
 var payment_switch=find_button(app,"无需付费")
 check(payment_switch!=null and not payment_switch.disabled,"test setup exposes free payment")
 payment_switch.button_pressed=true
 app.begin_battle(true)
 var view=app.duel_view;view.set_process(false)
 var game=view.engine
 game.phase="main";game.active=0;game.priority=0;game.pending={};game.stack=[];game.combat={}
 game.presentation_events.clear();view.reveal_player.reset()
 for p in game.players:p.field=[]
 view.render()
 check(view.debug_mode and game.debug_free_payment,"human versus AI match inherits both test switches")
 var help=view.responsive.tools_actions().filter(func(action):return action[0]=="测试说明")
 check(help.size()==1 and not help[0][2],"test match exposes operation guide in its tools menu")
 var before_help=game.revision
 view.open_debug_help()
 var guide=find_control(view.modal_root,"RichTextLabel")
 check(view.modal and guide!=null and "Z：加入当前回合玩家的手牌" in guide.text and "再按 C" in guide.text and not "C：加入" in guide.text,"guide explains injection and C copying without graveyard injection")
 view.close_overlay()
 check(not view.modal and game.revision==before_help,"closing guide preserves duel state")
 check(view.debug_card_matches("new-eto-002","unit") and view.debug_card_matches("token-fdf-127","item") and view.debug_card_matches("field-fdf-089","support"),"picker includes dream and token cards by zone")
 var unit_at=view.project(Vector3(0,0.03,1.5))
 var group=view.table.debug_field_group(view.stage_point(unit_at))
 check(group.get("owner",-1)==0 and group.get("group","")=="unit","field hit maps to player unit area")
 view.open_debug_card_picker(1,"field","unit")
 check(view.modal,"card picker opens")
 var search=view.modal_root.find_child("SearchInput",true,false)
 check(search!=null,"card picker has search")
 var added=pick_card(view,"new-eto-002")
 check(added and game.players[1].field.any(func(c):return c.card_id=="new-eto-002"),"picker adds selected card to selected side")
 game.presentation_events.clear();view.reveal_player.reset()
 game.active=1;game.priority=1
 var shortcut=InputEventKey.new();shortcut.pressed=true;shortcut.keycode=KEY_Z
 view._input(shortcut)
 check(view.modal,"Z opens the hand picker")
 check(pick_card(view,"96") and game.players[1].hand.any(func(c):return c.card_id=="96"),"Z adds a card to active player's hand")
 shortcut.keycode=KEY_X;view._input(shortcut)
 check(view.modal,"X opens the palette picker")
 check(pick_card(view,"53") and game.players[1].palette.any(func(c):return c.card_id=="53" and not c.tapped),"X adds an upright card to active player's palette")
 shortcut.keycode=KEY_C;view._input(shortcut)
 check(not view.modal,"C no longer opens the graveyard picker")
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=unit_at
 view.stage_input(click)
 check(view.modal,"left click on empty unit area opens picker")
 view.close_overlay()
 game.stack=[{"kind":"ability"}]
 check(not view.can_debug_add(),"injection is unavailable during a stack")
 game.stack.clear()
 print("DEBUG_INJECTION: existing tools checked")
 await ui_copy_checks(view)
 app.queue_free()
 print("DEBUG_INJECTION: %d checks; %d failures" % [checks,failures.size()])
 quit(1 if not failures.is_empty() else 0)
