extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
var failures=0
func _initialize(): call_deferred("run")
func run():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for seed_value in range(1,9):
  var e=Duel.new(); e.start(decks[0],decks[1],seed_value%2,seed_value*137)
  var steps=0; var stale=0; var revision=-1
  while steps<8000 and e.winner==-2:
   var who=e.pending.get("owner",e.priority)
   if e.phase=="mulligan": who=0 if not e.players[0].mulligan_done else 1
   e.ai_step(who); steps+=1
   if e.revision==revision: stale+=1
   else: stale=0
   revision=e.revision
   if stale>8:
    print("STALLED seed=",seed_value," phase=",e.phase," priority=",e.priority," pending=",e.pending," stack=",e.stack)
    break
  print("MATCH seed=%d first=%d steps=%d turns=%d winner=%d life=%s/%s" % [seed_value,seed_value%2,steps,e.turn,e.winner,e.players[0].life,e.players[1].life])
  if e.winner==-2: failures+=1
 print("V010_MATCHES: 8 matches; %d unfinished" % failures)
 quit(0 if failures==0 else 1)
