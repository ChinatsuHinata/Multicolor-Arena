extends SceneTree
const Archive=preload("res://scripts/replay_archive.gd")
const Training=preload("res://scripts/ai/replay_training.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
const Action=preload("res://scripts/ai/action.gd")
const State=preload("res://scripts/ai/simulation_state.gd")
const BASE="res://work/ai-training/strategic-2026-09-27"
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if not ok:failures.append(message);push_error(message)
func read(path: String):return Training.normalize_json(JSON.parse_string(FileAccess.get_file_as_string(path)))
func normalized(value):return Training.normalize_json(JSON.parse_string(JSON.stringify(value)))
func run():
 var manifest=read(BASE+"/manifest.json");var results=read(BASE+"/training-results.json")
 check(manifest.failures.is_empty(),"Extraction checks pass")
 var models={}
 for name in ["baseline-outcome-value","baseline-preference-value","strategic-outcome-value","strategic-preference-value"]:
  models[name]=Value.load_weights(BASE+"/"+name+".json")
  check(not models[name].is_empty(),"Runtime loads "+name)
 var outcomes=read(BASE+"/outcomes.json");var preferences=read(BASE+"/preferences.json")
 var train_groups={};var validation_groups={};var sample_keys={}
 for row in outcomes.samples:
  var key=row.group+":"+str(row.frame_index)+":"+str(row.seat)
  check(not sample_keys.has(key),"No duplicated replay/position/seat samples");sample_keys[key]=true
  if row.seed>=1000:validation_groups[row.group]=true
  else:train_groups[row.group]=true
  check(row.features.size()==results.feature_count and row.outcome in [-1,0,1],"Expanded features carry actual terminal labels")
  for weights in models.values():check(is_finite(Value.score_features(row.features,weights)),"Runtime model score is finite")
 for group in validation_groups:check(not train_groups.has(group),"Entire replay stays on one side of the split")
 for model in ["baseline","strategic"]:
  var weights=models[model+"-preference-value"]
  for ranking in results.models[model+"_preference"].ranking:
   var pair=preferences.pairs.filter(func(p):return p.group==ranking.group and p.frame_index==ranking.frame and p.seat==ranking.seat)[0]
   var margin=Value.score_features(pair.preferred,weights)-Value.score_features(pair.alternative,weights)
   check(is_equal_approx(margin,ranking.margin) and (margin>0)==ranking.preferred_ranked_higher,"Python and Godot agree on preference ranking")
 for replay in manifest.replays:
  check(FileAccess.get_sha256("res://replay/"+replay.file)==replay.sha256,"Original replay SHA remains unchanged")
  var doc=read(replay.annotation_file);var loaded=Archive.read("res://replay/"+replay.file)
  var training=Training.new();training.archive=loaded.archive
  if doc.annotations.is_empty():continue
  for row in [doc.annotations.front(),doc.annotations.back()]:
   var e=training.restore(row.frame_index)
   check(normalized(Value.strategic_features(e,row.seat))==row.features,"First/last extracted replay features reproduce")
  for row in doc.annotations:
   if row.teacher_action.is_empty():continue
   var e=training.restore(row.frame_index)
   for endpoint in [row.teacher_action,row.comparison_action]:
    check(normalized(Training.evaluate_action(e,row.seat,endpoint.action,true))==endpoint or normalized(Training.evaluate_action(e,row.seat,endpoint.action,true)).features==endpoint.features,"Preference endpoint reproduces with expanded features")
 var behavior=read(BASE+"/behavior.json")
 var seen={}
 for record in behavior.records:
  if seen.has(record.group):continue
  seen[record.group]=true
  var replay=manifest.replays.filter(func(r):return r.sha256==record.group)[0]
  var loaded=Archive.read("res://replay/"+replay.file);var training=Training.new();training.archive=loaded.archive
  var e=training.restore(record.frame_index);var checked=0
  for entry in record.legal_actions:
   if checked>=24:break
   check(Action.apply(State.fork(e,record.seat),record.seat,entry.action),"Sampled exported action is accepted by the authority")
   checked+=1
 save_report({"checks":checks,"failures":failures,"feature_count":results.feature_count,"verified_replays":manifest.replays.size(),"promotion":"experimental_only"})
 print("STRATEGIC CORPUS ",checks," checks; failures=",failures.size());quit(0 if failures.is_empty() else 1)
func save_report(data: Dictionary):
 var f=FileAccess.open(BASE+"/verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(data,"  "));f.close()
