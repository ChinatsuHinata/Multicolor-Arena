extends SceneTree

const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var failures=[]
var checks=0

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
 var search=find_control(view.modal_root,"LineEdit")
 if search==null:return false
 search.text=id;search.text_changed.emit(id)
 var panel=view.modal_root.get_child(0)
 for child in panel.get_children():
  if child is ScrollContainer:
   for row in child.get_child(0).get_children():
    if row is Button and ("["+id+"]") in row.text:
     row.pressed.emit();return true
 return false

func run():
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
 var app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
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
 for p in game.players:p.field=[]
 view.render()
 check(view.debug_mode and game.debug_free_payment,"human versus AI match inherits both test switches")
 var help=find_button(view,"测试说明")
 check(help!=null and not help.disabled,"test match exposes operation guide")
 var before_help=game.revision
 view.open_debug_help()
 var guide=find_control(view.modal_root,"RichTextLabel")
 check(view.modal and guide!=null and "Z：加入当前回合玩家的手牌" in guide.text and "梦违" in guide.text,"guide explains shortcuts and special cards")
 view.close_overlay()
 check(not view.modal and game.revision==before_help,"closing guide preserves duel state")
 check(view.debug_card_matches("new-eto-002","unit") and view.debug_card_matches("token-fdf-127","item") and view.debug_card_matches("field-fdf-089","support"),"picker includes dream and token cards by zone")
 var unit_at=view.project(Vector3(0,0.03,1.5))
 var group=view.table.debug_field_group(view.stage_point(unit_at))
 check(group.get("owner",-1)==0 and group.get("group","")=="unit","field hit maps to player unit area")
 view.open_debug_card_picker(1,"field","unit")
 check(view.modal,"card picker opens")
 var search=find_control(view.modal_root,"LineEdit")
 check(search!=null,"card picker has search")
 search.text="new-eto-002";search.text_changed.emit(search.text)
 var panel=view.modal_root.get_child(0)
 var added=false
 for child in panel.get_children():
  if child is ScrollContainer:
   var rows=child.get_child(0)
   for row in rows.get_children():
    if row is Button and "new-eto-002" in row.text:
     row.pressed.emit();added=true;break
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
 check(view.modal,"C opens the graveyard picker")
 check(pick_card(view,"new-eto-008") and game.players[1].grave.any(func(c):return c.card_id=="new-eto-008"),"C adds dream card to active player's graveyard")
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=unit_at
 view.stage_input(click)
 check(view.modal,"left click on empty unit area opens picker")
 view.close_overlay()
 game.stack=[{"kind":"ability"}]
 check(not view.can_debug_add(),"injection is unavailable during a stack")
 game.stack.clear()
 app.queue_free()
 print("DEBUG_INJECTION: %d checks; %d failures" % [checks,failures.size()])
 quit(1 if not failures.is_empty() else 0)
