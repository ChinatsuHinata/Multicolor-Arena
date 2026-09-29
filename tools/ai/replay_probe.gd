extends SceneTree
## Fixed counterfactual regression cases from the reviewed replay. This is a
## public opponent approximation, not a reconstruction of hidden future draws.
const Archive=preload("res://scripts/replay_archive.gd")
const Duel=preload("res://scripts/rules/duel_engine.gd")
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
const Action=preload("res://scripts/ai/action.gd")
const Round=preload("res://scripts/ai/public_round.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
var replay_path="res://replay/2026-09-27T03-07-55 你 vs 人机_1016025273.mreply"
var output="res://work/ai-training/replay-probe.json"
var archive
func _initialize():call_deferred("run")
func engine(index: int):
 var state=archive.frame(index).projection.state
 var e=Duel.new()
 for key in state:
  if key not in ["players","pending","forced_cast","presentation_events"]:e.set(key,state[key].duplicate(true) if state[key] is Array or state[key] is Dictionary else state[key])
 e.players=state.players.duplicate(true);e.cards.merge(archive.definitions,true)
 # Replay projection serializes shared references separately. Repair them
 # before any rule resolution; simulation itself uses the alias-aware codec.
 for p in e.players:
  for c in p.field+p.hand+p.grave+p.exile:
   if c.uid==p.leader.uid:p.leader=c
   for j in range(p.get("extra_leaders",[]).size()):
    if c.uid==p.extra_leaders[j].uid:p.extra_leaders[j]=c
 e.next_uid=1000000;e.next_stack=1000000;e.recorded_life=e.players.map(func(p):return p.life)
 e.ai_profiles=["",AI.PROFILE];e.ai_memory=[{},{}]
 return AI.simulation(e,1)
func cast_id(e,id: String) -> bool:
 var offered=e.players[1].hand.filter(func(c):return c.card_id==id)
 if id==AI.REMILIA:offered=[e.players[1].leader]
 if offered.is_empty():return false
 return Action.apply(e,1,{"kind":"cast","uid":offered[0].uid,"target":{"none":true}}) and AI.settle_sim(e,1)
func run():
 var read=Archive.read(replay_path)
 if not read.has("archive"):push_error("Replay unavailable");quit(1);return
 archive=read.archive
 var cases=[{"frame":211,"name":"T11 wings then aya","route":[AI.WINGS,AI.AYA]},
 {"frame":211,"name":"T11 aya then lily","route":[AI.AYA,AI.LILY]},
 {"frame":300,"name":"T15 aya then remilia","route":[AI.AYA,AI.REMILIA]},
 {"frame":300,"name":"T15 fairy then remilia then lily","route":[AI.FAIRY,AI.REMILIA,AI.LILY]}]
 var failures=0
 for case in cases:
  var e=engine(case.frame);var valid=true
  for id in case.route:
   if not cast_id(e,id):valid=false;break
  case.legal=valid;case.before_round=Value.features(e,1)
  if valid:
   var outlook=Round.rollout(e,1,AI)
   case.complete=outlook.complete;case.reason=outlook.reason;case.steps=outlook.steps;case.after_round=outlook.features;case.value=outlook.value
   if not outlook.complete:failures+=1
  else:failures+=1
  print("PROBE ",JSON.stringify(case))
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file=FileAccess.open(output,FileAccess.WRITE)
 if file==null:push_error("Could not write probe");quit(1);return
 file.store_string(JSON.stringify({"replay":replay_path,"information":"own hand and public zones; no remembered opposing reveals in this probe","opponent":"bounded public policy with neutral future draws","cases":cases}));file.close()
 quit(0 if failures==0 else 1)
