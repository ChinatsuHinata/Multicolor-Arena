extends "res://tests/test_v010_matches.gd"
func run():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 var pools=[["2","3","7","8","13","46","77","80","97","101","102","107","111","113","122","124","129","153","155","171","172"],["17","24","25","26","32","34","43","47","51","52","59","60","62","63","74","76","93","103","105","109","116","119","123","125","132","136","137","138","140","145","146","148","150","152","154","156","157","159","160","173","175","178","spell-kmo-004","spell-kmo-002","spell-kmo-005","spell-smm-006"]]
 pools[0].append_array(["character-ucs-032","character-ucs-048","character-ucs-069","character-ucs-072","spell-ucs-008","spell-ucs-014","spell-ucs-019"])
 pools[1].append_array(["character-ucs-038","character-ucs-042","character-ucs-071","item-ucs-012","spell-ucs-011","spell-ucs-026","spell-ucs-027","spell-ucs-029"])
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
  print("EXCEL_MATCH seed=%d steps=%d turns=%d winner=%d life=%s/%s" % [seed_value,steps,e.turn,e.winner,e.players[0].life,e.players[1].life])
  if e.winner==-2:failures+=1
 print("V011_MATCHES: 8 mixed-new-card matches; %d unfinished" % failures);quit(0 if failures==0 else 1)
