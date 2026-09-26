extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
const DB=preload("res://scripts/card_database.gd")
var checks=0
var failures=[]
var e
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func _initialize(): call_deferred("run")
func fresh():
 var deck=Store.blank("规则测试"); deck.leader="70"
 for i in range(50): deck.main.append("164")
 e=Duel.new(); e.start(deck,deck,0,12)
 for p in e.players:
  p.hand=[]; p.field=[]; p.palette=[]; p.grave=[]; p.exile=[]; p.potato=false; p.mulligan_done=true; p.turns=3
 e.presentation_events.clear()
 e.phase="main"; e.active=0; e.priority=0; e.turn=5
func put(id: String,zone: String="field",who: int=0):
 var c=e.make_card(id,who,zone); e.players[who][zone].append(c); c.entered_turns=0; return c
func mana():
 for id in ["165","167","166","164","168"]:
  for i in range(8): put(id,"palette")
func one(): e.pass_priority(e.priority); e.pass_priority(e.priority)
func settle():
 for i in range(80):
  if e.winner!=-2: return
  e.pump_choices()
  if not e.pending.is_empty():
   match e.pending.kind:
    "trigger_order": e.choose_trigger_order(0)
    "effect_choice": e.choose_effect(e.pending.options[0])
    "leader_return": e.choose_return(false)
    "trigger": e.choose_trigger({})
    "timer": e.choose_timer(0)
    _: return
  elif not e.stack.is_empty(): one()
  else: return
 push_error("settle exceeded limit")
func cast(id: String,target: Dictionary={},zone: String="hand"):
 var c=put(id,zone)
 var choices=e.targets_for(id,0)
 if target.is_empty() and e.cards[id].kind=="符卡" and not choices.is_empty(): target=choices[0]
 var error=e.commit_cast(0,c.uid,target,e.payment(0,e.cast_cost(0,c)).plan)
 expect(error.is_empty(),"cast "+id+" "+error)
 settle(); e.priority=0
 return c
func enter(id: String,who: int=0):
 var c=e.make_card(id,who,"hand"); e.enter_field(c,who); e.pump_choices(); return c
