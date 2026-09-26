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
