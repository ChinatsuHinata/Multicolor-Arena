extends SceneTree
const Config=preload("res://scripts/tutorial/config.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Progress=preload("res://scripts/tutorial/progress.gd")
const Store=preload("res://scripts/deck_store.gd")
const Generated=preload("res://tests/support/tutorial_generated_units.gd")
var checks=0
var failures=[]
var directory="res://work/tutorial-progress-"+str(Time.get_ticks_usec())

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func progress():
 var value=Progress.new();value.directory=directory
 return value

func write_without_definitions(data: Dictionary,id: String,snapshot: Dictionary):
 var saved=progress();var state=saved.portable(snapshot)
 state.adapter.game.erase("definitions")
 for scene in state.scenario_states.values():scene.adapter.game.erase("definitions")
 var file=FileAccess.open_compressed(saved.step_path(data,id),FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
 file.store_var({"version":Progress.VERSION,"signature":saved.signature(data),"snapshot":state});file.close()

func definitions_match(snapshot: Dictionary,expected: Dictionary,label: String) -> bool:
 var definitions=snapshot.get("adapter",{}).get("game",{}).get("definitions",{})
 var matches=expected.keys().all(func(id):return definitions.get(id)==expected[id])
 expect(matches,label)
 return matches

func check_final_puzzle():
 var loaded=Config.new().load_file("res://data/tutorial/beginner/t3.json",Store.CARDS)
 expect(loaded.ok,"unit lesson validates")
 if not loaded.ok:return
 var data=loaded.data;var flow=Runtime.new()
 expect(flow.start(data,Store.CARDS,"d16","leader_task").is_empty(),"enter the real step preceding the final puzzle")
 expect(flow.next() and flow.current_step=="r3","sequential entry reaches the final puzzle")
 var expected={};var original=flow.capture()
 for alias in ["frog_one","frog_two","frog_three"]:
  var card=flow.adapter.entity(alias);expected[card.card_id]=flow.adapter.engine.cards[card.card_id].duplicate(true)
 expect(progress().save(data,"r3",original),"save the real final-puzzle entrance")
 var saved=progress().snapshot(data,"r3",Store.CARDS)
 if definitions_match(saved,expected,"directory checkpoint retains all three generated frog definitions"):
  var resumed=Runtime.new();resumed.start(data,Store.CARDS)
  expect(resumed.restore(saved),"cold runtime restores the directory checkpoint")
  for alias in ["frog_one","frog_two","frog_three"]:
   var card=resumed.adapter.entity(alias);var engine=resumed.adapter.engine
   expect(engine.stat(card,"power")==4 and engine.stat(card,"health")==4 and engine.stat(card,"spirit")==2,alias+" retains 4/4/2 stats")
   expect(engine.cards[card.card_id].copy_source_id=="token-ucs-098" and "不占战场格" in engine.cards[card.card_id].keywords,alias+" retains art and rules")
  resumed.adapter.entity("frog_one").damage=2
  expect(resumed.reset_task() and resumed.adapter.entity("frog_one").damage==0,"directory task reset retains the generated definitions")
  resumed.free()
 # Existing progress already lost definitions. Rebuild only the definitions,
 # preserving the saved graph, instance aliases, damage and random state.
 flow.adapter.entity("frog_one").damage=1;flow.adapter.engine.players[0].life=7
 flow.adapter.engine.rng.randi();var rng_state=flow.adapter.engine.rng.state
 write_without_definitions(data,"r3",flow.capture())
 saved=progress().snapshot(data,"r3",Store.CARDS)
 if definitions_match(saved,expected,"existing final-puzzle records recover their configured frog definitions"):
  var resumed=Runtime.new();resumed.start(data,Store.CARDS);resumed.restore(saved)
  expect(resumed.adapter.entity("frog_one").damage==1 and resumed.adapter.engine.players[0].life==7 and resumed.adapter.engine.rng.state==rng_state,"definition recovery preserves the exact saved game state")
  resumed.free()
 flow.free()

func check_generated_units():
 var database=Store.CARDS.duplicate(true)
 var data={"schema_version":1,"id":"generated_progress","title":"动态衍生物目录恢复","initial_scenario":"battle","start_step":"intro","completion":{"type":"always"},
  "scenarios":{"battle":Generated.scene(),"deck":{"type":"deck","deck":Generated.Model.deck()}},
  "steps":{"intro":{"type":"info","guide":{"text":"生成衍生物。"},"next":"after"},
   "after":{"type":"info","guide":{"text":"查看生成的衍生物。"},"next":"away"},
   "away":{"type":"info","scenario":"deck","guide":{"text":"切换场景。"},"next":"back"},
   "back":{"type":"info","scenario":"battle","scenario_mode":"resume","guide":{"text":"恢复战场。"},"next":"$complete"}}}
 var flow=Runtime.new()
 expect(flow.start(data,Store.CARDS).is_empty(),"generated-unit course starts")
 expect(Generated.cast(flow.adapter).is_empty(),"real spell creates tokens")
 var engine=flow.adapter.engine
 var token=engine.units(0).filter(func(card):return card.get("token",false))[0]
 var clone=engine.Cat.copy_token(engine,0,token)
 expect(not clone.is_empty(),"real copy effect creates a dynamic token definition")
 expect(not engine.Cat.token(engine,0,"青蛙",2,5,3,["蓝","绿"],["不占战场格"]).is_empty(),"real token effect creates custom attributes")
 var expected={}
 for card in engine.units(0).filter(func(unit):return unit.get("token",false)):
  expected[card.card_id]=engine.cards[card.card_id].duplicate(true)
 expect(flow.next() and progress().save(data,"after",flow.checkpoint),"save the step after token creation")
 var original=flow.checkpoint
 var saved=progress().snapshot(data,"after",Store.CARDS)
 definitions_match(saved,expected,"cold directory read retains spell-generated tokens and copies")
 var on_disk=progress().portable(original).adapter.game.get("definitions",{})
 expect(not on_disk.has("70"),"portable snapshot omits unchanged database cards")
 expect(flow.next() and progress().save(data,"away",flow.checkpoint),"save a non-battle scene with an inactive battlefield")
 saved=progress().snapshot(data,"away",Store.CARDS)
 var inactive=saved.get("scenario_states",{}).get("battle",{})
 if definitions_match(inactive,expected,"inactive battle retains its dynamic definitions across disk restore"):
  var resumed=Runtime.new();resumed.start(data,Store.CARDS);resumed.restore(saved)
  expect(resumed.next() and resumed.current_step=="back","scene resume returns to the saved battlefield")
  definitions_match(resumed.capture(),expected,"resumed scene keeps token and copy attributes")
  resumed.free()
 # A discarded definition created by a free action cannot be guessed safely.
 write_without_definitions(data,"after",original)
 var reader=progress()
 expect(reader.snapshot(data,"after",Store.CARDS).is_empty() and not reader.last_error.is_empty(),"incomplete generated-unit records fail before restoring a broken engine")
 expect(reader.has_read(data,"after") and reader.save(data,"after",original),"rereading repairs an incomplete record without losing read progress")
 definitions_match(progress().snapshot(data,"after",Store.CARDS),expected,"repaired record retains all generated definitions")
 expect(Store.CARDS==database,"restoring generated definitions does not pollute the shared card database")
 flow.free()

func _initialize():
 check_final_puzzle()
 check_generated_units()
 print("TUTORIAL PROGRESS: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
