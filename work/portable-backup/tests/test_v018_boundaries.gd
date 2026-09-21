extends SceneTree
const Session=preload("res://net/lan_session.gd")
const Store=preload("res://scripts/deck_store.gd")
const View=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
var checks=0
var failures=[]
func _init():call_deferred("run")
func check(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)
func run():
 var e=Session.Duel.new();var decks=Store.load_decks().decks;e.start(decks[0],decks[1],0,729)
 for p in e.players:
  for z in ["hand","field","palette","grave","exile"]:p[z]=[]
  p.turns=3;p.mulligan_done=true
 e.active=0;e.priority=0;e.phase="main";e.turn=6;e.presentation_events=[]
 var sunny=e.make_card("1",0,"stack");e.stack.append({"id":77,"kind":"card","card":sunny,"owner":0,"target":{},"name":e.cards["1"].name});e.next_stack=78
 e.pass_priority(0);e.pass_priority(1)
 check(e.pending.get("kind","") in ["trigger","effect_choice"],"ETB target choice pending")
 var snapshot=Session.Codec.capture(e);var rng_before=e.rng.state
 for seat in [0,1]:
  var before=Session.Codec.capture(e);var packet=View.build(e,seat,e.presentation_events)
  check(Session.Codec.capture(e)==before,"projection preserves full state seat "+str(seat))
  var facade=Remote.new();facade.seat=seat;facade.apply_snapshot(packet)
  check(facade.pending.get("kind","")!=("network_wait") if e.pending.owner==seat else facade.pending.kind=="network_wait","pending owner visibility")
 var clone=Session.Duel.new();Session.Codec.restore(clone,bytes_to_var(var_to_bytes(snapshot)))
 check(clone.pending==e.pending and clone.stack==e.stack,"pending ETB and stack restored")
 check(clone.rng.state==rng_before,"RNG state restored")
 var target=e.pending.options[0];var op="choose_effect" if e.pending.kind=="effect_choice" else "choose_trigger"
 var action={"name":op,"args":[target]}
 check(Session.Gateway.apply(e,0,action).is_empty() and Session.Gateway.apply(clone,0,action).is_empty(),"same pending choice accepts after recovery")
 check(Session.Codec.capture(e)==Session.Codec.capture(clone),"recovered trigger produces identical state")
 var guard=Session.Codec.capture(e)
 check(Session.Gateway.apply(e,1,{"name":"debug_move","args":[sunny.uid,"grave"]})!="","unknown/debug command rejected")
 check(Session.Gateway.apply(e,1,{"name":"choose_trigger_order","args":[0]})!="","wrong player and phase rejected")
 check(Session.Gateway.apply(e,0,{"name":"commit_cast","args":[sunny.uid,{},[{"uid":"bad","color":"蓝"}]]})!="","malformed payment rejected")
 check(Session.Gateway.apply(e,0,{"name":"attack","args":[sunny.uid,{"player":99},[]]})!="","invalid target seat rejected")
 check(Session.Codec.capture(e)==guard,"rejected commands leave state untouched")
 check(Session.Gateway.safe_value({"args":[{&"selection_id":"search",&"picks":[[{&"uid":7,&"epoch":0,&"zone":"deck"}]]}]}),"Godot StringName keys accepted")
 var series=Session.Series.new();series.setup(3,false)
 for seat in [0,1]:series.set_deck(seat,decks[seat])
 check(series.ready(0)!="","ready waits for first-player choice")
 series.state.first_chosen=true;series.ready(0);series.ready(1);series.start_game()
 series.record_result(-1);check(series.state.status=="between" and series.state.scores==[0,0],"draw does not count as win")
 check(not series.record_result(0),"game result id deduplicates")
 var changed=series.state.decks[0].duplicate(true)
 var id=changed.main.pop_back();changed.side.append(id)
 check(series.set_deck(0,changed)!="","sideboard preserves main-deck size")
 # Paying an optional free-cast grant must validate against paid X options.
 e.pending={};e.stack=[];e.combat={};e.priority=0
 var byakuren=e.make_card("character-fdf-ex03",0,"hand");e.players[0].hand.append(byakuren)
 for mana_id in ["166","166","164"]:
  var mana=e.make_card(mana_id,0,"palette");e.players[0].palette.append(mana)
 e.players[0].field.append(e.make_card("166",0,"field"))
 e.Cat.grant_cast(e,byakuren,0,true)
 var projected=View.build(e,0);var proxy=Remote.new();proxy.seat=0;proxy.apply_snapshot(projected);proxy.set_granted_payment(true)
 var options=proxy.pending.options.filter(func(o):return o.get("x",0)==1)
 check(not options.is_empty(),"paid grant exposes X=1")
 if not options.is_empty():
  var target_paid=options[0].duplicate(true);var price=proxy.Cat.granted_cost(proxy,proxy.pending.trigger,target_paid);target_paid.payment=proxy.payment(0,price).plan
  var error=Session.Gateway.apply(e,0,{"name":"choose_effect","args":[target_paid],"paid_uid":byakuren.uid,"grant_payment":true})
  check(error.is_empty() and byakuren.zone=="stack","paid grant commits X=1 through gateway")
 var journal="res://work/v018/boundary-journal.bin"
 check(Session.Journal.save_to(journal,{"engine":snapshot})==OK,"checkpoint saved")
 check(Session.Journal.save_to(journal,{"engine":snapshot,"second":true})==OK,"checkpoint replaced atomically")
 var file=FileAccess.open(journal,FileAccess.WRITE);file.store_string("broken");file.close()
 var recovered=Session.Journal.load_from(journal)
 check(recovered.has("engine") and not recovered.has("second"),"corrupt newest checkpoint falls back to previous generation")
 print("V018 BOUNDARIES ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
