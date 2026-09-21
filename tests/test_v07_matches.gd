extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var failures=[]
var checks=0
func _initialize(): call_deferred("run")
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func run():
 var deck=Store.blank("15种卡完整对局测试"); deck.leader="70"
 for id in ["50","53","54","56","57","68","70","96","99","100","112","164","165","167","170"]:
  if id=="70": continue
  for i in range(3): deck.main.append(id)
 for id in ["50","53","54","56","57","96","112","164"]: deck.main.append(id)
 expect(Store.validate(deck,true).is_empty(),"expanded pool builds a legal 50-card deck with at most four copies")
 var observed={}; var reports=[]
 for seed_value in range(1,7):
  var e=Duel.new(); e.start(deck,deck,seed_value%2,seed_value+70)
  e.mulligan(0,[]); e.mulligan(1,[])
  var actions=0
  for step in range(1800):
   if e.winner!=-2: break
   var prior=e.revision
   e.ai_step(e.pending.get("owner",e.priority)); actions+=1
   for entry in e.stack:
    if entry.kind=="card": observed[entry.card.card_id]=true
   if prior==e.revision: break
  expect(e.winner!=-2,"new-card match seed %d completes without stalled command" % seed_value)
  reports.append({"seed":seed_value+70,"actions":actions,"turns":e.turn,"winner":e.winner,"result":e.log.back()})
 for id in ["50","53","54","56","57","96","112"]: expect(observed.has(id),"AI actually uses new card "+Store.CARDS[id].name)
 var file=FileAccess.open("res://work/v07-new-matches.json",FileAccess.WRITE); file.store_string(JSON.stringify(reports,"  "))
 print("V07_MATCHES: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
