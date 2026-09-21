extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var checks=0
var failures=[]
func _initialize(): call_deferred("run")
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func run():
 var reports=[]
 var observed={}
 var new_pool=JSON.parse_string(FileAccess.get_file_as_string("res://work/v09-import-manifest.json")).map(func(x): return x.id)
 new_pool.append_array(["91","133","rec_unit_097","soi_unit_086"])
 for sample in range(8):
  var d=Store.blank("Expanded pool regression"); d.leader=["70","71","75","78","79","87","91","soi_unit_086"][sample]
  var pool=new_pool.duplicate()
  pool.append_array(["53","54","57","96","112","164","165","167","170"])
  var at=sample*6
  while d.main.size()<50:
   var id=pool[at%pool.size()]; at+=1
   if id==d.leader or ("终言" in Store.CARDS[id].get("keywords",[]) and id in d.main): continue
   d.main.append(id)
  expect(Store.validate(d,true).is_empty(),"new pool forms legal 50 card deck "+str(sample))
  var e=Duel.new(); e.start(d,d,sample%2,sample+190)
  e.mulligan(0,[]); e.mulligan(1,[])
  var steps=0
  for i in range(2500):
   if e.winner!=-2: break
   var before=e.revision
   e.ai_step(e.pending.get("owner",e.priority)); steps+=1
   for entry in e.stack:
    if entry.kind=="card": observed[entry.card.card_id]=true
   if before==e.revision:
    print("STALLED:",e.phase," pending=",e.pending," stack=",e.stack," combat=",e.combat)
    break
  expect(e.winner!=-2,"expanded match completes "+str(sample))
  reports.append({"seed":sample+190,"winner":e.winner,"turns":e.turn,"steps":steps,"result":e.log.back()})
 var used=observed.keys().filter(func(id): return id in new_pool)
 expect(used.size()>=20,"AI actually used at least 20 new card types: "+str(used.size()))
 var file=FileAccess.open("res://work/v09-matches.json",FileAccess.WRITE); file.store_string(JSON.stringify({"matches":reports,"new_cards_used":used},"  ")); file.close()
 print("V09_MATCHES: %d checks; %d failures" % [checks,failures.size()]); quit(1 if not failures.is_empty() else 0)
