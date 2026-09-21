extends "res://tests/test_v010_matches.gd"
func run():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 var pools=[["character-fdf-112","7","8","character-fdf-117","character-fdf-115","spell-fdf-012","character-fdn-004","character-fdf-100","character-fdf-098","item-fdn-044","spell-ucs-052","spell-fdn-030","character-fdn-021","character-fdn-024","character-fdn-007","character-fdn-006","spell-ucs-022","spell-fdf-061","spell-fdf-074","character-ucs-016"],["character-fdf-119","character-fdf-041","spell-fdf-024","spell-fdf-040","spell-ucs-031","character-fdn-042","spell-fdf-018","spell-fdn-019","character-fdf-101","character-fdn-027","character-fdf-102","character-ucs-065","spell-fdf-049","spell-fdf-079","spell-fdf-078","spell-fdf-077","spell-fdf-076","spell-fdf-075","spell-fdn-002","character-ucs-068"]]
 for seed_value in range(1,13):
  var ds=decks.duplicate(true)
  for p in range(2):
   for i in range(40):ds[p].main[i]=pools[p][(i+seed_value*7)%pools[p].size()]
  var e=Duel.new();e.start(ds[0],ds[1],seed_value%2,seed_value*173)
  var steps=0;var stale=0;var revision=-1
  while steps<9000 and e.winner==-2:
   var who=e.pending.get("owner",e.priority)
   if e.phase=="mulligan":who=0 if not e.players[0].mulligan_done else 1
   e.ai_step(who);steps+=1
   stale=stale+1 if e.revision==revision else 0;revision=e.revision
   if stale>8:print("STALLED ",seed_value," ",e.phase," ",e.pending," ",e.stack);break
  print("V013_MATCH seed=%d steps=%d turns=%d winner=%d life=%s/%s" % [seed_value,steps,e.turn,e.winner,e.players[0].life,e.players[1].life])
  if e.winner==-2:failures+=1
 print("V013_MATCHES: 12 mixed new card matches; %d unfinished" % failures);quit(0 if failures==0 else 1)
