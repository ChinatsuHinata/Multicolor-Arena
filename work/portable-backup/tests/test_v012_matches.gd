extends "res://tests/test_v010_matches.gd"
func run():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 var pools=[["character-lof-001","character-lof-003","character-lof-017","character-fdn-068","character-ucs-007","spell-lof-007","spell-lof-025","spell-fdn-066","spell-fdf-083","spell-htk-018","spell-fdn-069","9","2","3","13","164","167"],["character-htk-001","character-htk-002","character-fdn-067","spell-htk-003","spell-fdf-083","spell-htk-018","spell-fdn-069","164","167","168","50","51","99","96","111","item-ucs-012"]]
 for seed_value in range(1,9):
  var ds=decks.duplicate(true)
  for p in range(2):
   for i in range(35):ds[p].main[i]=pools[p][(i+seed_value*7)%pools[p].size()]
  var e=Duel.new();e.start(ds[0],ds[1],seed_value%2,seed_value*137)
  var steps=0;var stale=0;var revision=-1
  while steps<9000 and e.winner==-2:
   var who=e.pending.get("owner",e.priority)
   if e.phase=="mulligan":who=0 if not e.players[0].mulligan_done else 1
   e.ai_step(who);steps+=1
   stale=stale+1 if e.revision==revision else 0;revision=e.revision
   if stale>8:print("STALLED ",seed_value," ",e.phase," ",e.pending," ",e.stack);break
  print("V012_MATCH seed=%d steps=%d turns=%d winner=%d life=%s/%s" % [seed_value,steps,e.turn,e.winner,e.players[0].life,e.players[1].life])
  if e.winner==-2:failures+=1
 print("V012_MATCHES: 8 mixed-new-card matches; %d unfinished" % failures);quit(0 if failures==0 else 1)
