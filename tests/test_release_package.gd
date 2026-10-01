extends SceneTree
const Policy=preload("res://addons/share_export/release_policy.gd")
const Store=preload("res://scripts/deck_store.gd")
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
var failures=[]
var checks=0

func check(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)

func _initialize():
 var presets=Store.load_decks(Store.SAVE_PATH)
 check(not presets.has("error"),"Preset collection loads")
 var portable=[]
 for path in Store.scan_files("res://deck"):
  var parsed=Store.read_file(path)
  if parsed.has("deck"):portable.append(parsed.deck)
 var source=presets.decks.duplicate(true)
 var test=source[0].duplicate(true);test.id="test_fixture";test.rule_set="test"
 var other_ai=source[0].duplicate(true);other_ai.id="other_ai";other_ai.name="其他人机（AI）"
 var trial=source[0].duplicate(true);trial.id="trial_fixture";trial.name="试验模型"
 source.append_array([test,other_ai,trial])
 var original=JSON.stringify([source,portable])
 var release=Policy.select_decks(source,portable)
 check(not release.has("error"),"Release selection succeeds")
 if not release.has("error"):
  check(release.decks.size()==presets.decks.size()+1,"Existing presets plus approved AI only")
  check(release.decks.all(func(d):return d.id not in [test.id,other_ai.id,trial.id]),"Test and other AI decks excluded")
  for deck in release.decks:
   check(Store.validate(deck,true,str(deck.get("rule_set","official"))).is_empty(),"Release deck is legal: "+deck.name)
  var remilia=release.decks[-1]
  check(remilia.id==Policy.REMILIA_ID and remilia.name=="蕾米速攻（AI）","Approved AI uses the Android display name")
  check(AI.profile(remilia)==AI.PROFILE,"Renamed deck retains dedicated AI")
  var named=remilia.duplicate(true);named.main=[]
  check(AI.profile(named)==AI.PROFILE,"New display name independently selects AI")
 check(JSON.stringify([source,portable])==original,"Packaging does not edit source decks")
 check(Policy.select_decks(presets.decks,[]).has("error"),"Missing approved AI blocks export")
 for path in ["res://test/probe.gd","res://tests/test_rules.gdc","res://training/corpus.json","res://models/value.onnx","res://data/test_precons.json","res://data/experimental-weights.json","res://work/experiment.bin"]:
  check(Policy.excluded_path(path),"Excluded: "+path)
 for path in ["res://scripts/ai/decision_agent.gd","res://scripts/ai/matchup_models.gd","res://scripts/rules/remilia_aggro_ai.gd","res://data/bundled_decks.json","res://data/alternate_art.json","res://cards/spell-fdn-010.json"]:
  check(not Policy.excluded_path(path),"Runtime retained: "+path)
 print("Release package policy: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
