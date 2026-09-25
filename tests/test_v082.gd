extends SceneTree
var app
var view
var e
var checks=0
var failures=[]
func _initialize(): call_deferred("run")
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func put(who: int,id: String,zone: String):
 var c=e.make_card(id,who,zone); e.players[who][zone].append(c); return c
func clean():
 view.close_overlay(); view.local={}; view.selection=[]; view.drag_uid=0; view.dragging=false
 e.cards=preload("res://scripts/card_database.gd").load_cards()
 e.start(app.decks[app.player_choice],app.decks[app.ai_choice],1,39)
 for p in e.players:
  p.field=[]; p.hand=[]; p.palette=[]; p.grave=[]; p.potato=false; p.mulligan_done=true
 e.phase="main"; e.turn=4; e.active=1; e.priority=1; e.pending={}
 view.response_mode=view.ResponseMode.DEFAULT; view.previous_snapshot={}; view.table.last_combat={}
 e.presentation_events.clear();view.reveal_player.reset()
func find_button(node: Node,title: String):
 if node is Button and node.text==title: return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found: return found
 return null
func tick(): view.clock_time=2; view._process(1)
func snapshot(): return JSON.stringify({"players":e.players,"stack":e.stack,"pending":e.pending,"priority":e.priority,"revision":e.revision,"log":e.log})
func stack_fixture(available: bool) -> Dictionary:
 clean()
 var counter={}
 if available:
  put(0,"70","field"); put(0,"164","palette"); put(0,"164","palette")
  counter=put(0,"100","hand")
 put(1,"165","palette"); put(1,"164","palette")
 var spell=put(1,"96","hand")
 e.commit_cast(1,spell.uid,{"player":0},e.payment(1,{"红":1,"黄":1}).plan)
 return counter
func run():
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.load_legacy_test_decks()
 app.begin_battle(true)
 view=app.duel_view
 view.set_process(false)
 view.fast_mode=true
 e=view.engine
 expect(view.response_mode==view.ResponseMode.DEFAULT,"new duel starts in default response mode")
 for mode in [view.ResponseMode.ON,view.ResponseMode.DEFAULT,view.ResponseMode.OFF]:
  for available in [false,true]:
   var counter=stack_fixture(available)
   expect(e.has_response(0)==available,"fixture has expected legal response: "+str(available))
   e.presentation_events.clear()
   view.reveal_player.reset()
   view.set_response_mode(mode)
   var ask=mode==view.ResponseMode.ON or mode==view.ResponseMode.DEFAULT and available
   expect(view.should_ask_response()==ask,"response mode asks only when configured")
   expect((find_button(view.ui,"不响应 / 继续")!=null)==ask,"response prompt matches mode")
   if mode==view.ResponseMode.OFF and available:
    expect(counter.uid not in view.highlights(),"off mode does not advertise response cards")
   var before=e.revision
   tick()
   expect(e.revision==before if ask else e.priority==1,"response waits or passes according to mode")
 var card=stack_fixture(true)
 e.presentation_events.clear()
 view.reveal_player.reset()
 view.set_response_mode(view.ResponseMode.ON)
 view.selection=[card.uid]
 view.local={"uid":card.uid,"mode":"payment"}
 var public_before=snapshot()
 view.set_response_mode(view.ResponseMode.OFF)
 expect(view.selection.is_empty() and view.local.is_empty() and snapshot()==public_before,"switching off clears private response without changing game state")
 print("V082_TEST: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
