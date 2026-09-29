extends SceneTree
## Freeze a recent replay manifest, re-extract strategic features, preserve human
## labels, and record behavior with all matching payment variants (not fake labels).
const Archive=preload("res://scripts/replay_archive.gd")
const Training=preload("res://scripts/ai/replay_training.gd")
const Observation=preload("res://scripts/ai/observation.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
const Env=preload("res://scripts/ai/game_environment.gd")
const Actions=preload("res://scripts/ai/algorithm_actions.gd")
const Pressure=preload("res://scripts/ai/pressure_policy.gd")
var options={"since":"2026-09-26T23","output":"res://work/ai-training/strategic-2026-09-27","limit":"30","reuse-behavior":"false"}
var report={"replays":[],"excluded":[],"feature_schema":Value.Strategic.SCHEMA,"human_labels":0,"preference_pairs":0,"samples":0,"behaviors":0,"truncated_menus":0,"rejected_actions":0,"hidden_hand_skips":0,"checks":0,"failures":[]}

func pressure_pair(e,seat: int,menu: Dictionary) -> Dictionary:
 if e.players[seat].leader.card_id!="74":return {}
 var hold=Training.evaluate_action(e,seat,{"kind":"pass"},true)
 if not hold.get("endpoint_complete",false):return {}
 var initial=Value.strategic_features(e,seat);var forced=initial.required_gungnir_reserve>0
 var hold_score=Pressure.objective(e,seat,hold.features,hold.winner)
 var best={};var unsafe={};var best_score=hold_score;var unsafe_score=-INF;var inspected=0;var seen={}
 for entry in menu.actions:
  var a=entry.action
  if a.kind!="cast" or a.card_id not in ["169","spell-fdf-037","129","143","spell-fdf-035"]:continue
  if a.card_id=="143" and a.target.get("mode","")!="失去生命":continue
  var signature=Actions.key(a)
  if seen.has(signature):continue
  seen[signature]=true;inspected+=1
  if inspected>16:break
  var endpoint=Training.evaluate_action(e,seat,a,true)
  if not endpoint.get("endpoint_complete",false):continue
  var score=Pressure.objective(e,seat,endpoint.features,endpoint.winner)
  if forced and endpoint.features.gungnir_payable==0 and endpoint.winner!=seat:
   if score>unsafe_score:unsafe=endpoint;unsafe_score=score
   continue
  if score>best_score+0.01:best_score=score;best=endpoint
 if not best.is_empty():return {"teacher":best,"comparison":hold,"risk":initial.upcoming_gungnir_threat,"margin":best_score-hold_score,"reason":"pressure_route_without_forfeiting_required_response"}
 if forced and not unsafe.is_empty():return {"teacher":hold,"comparison":unsafe,"risk":1.0,"margin":hold_score-unsafe_score,"reason":"public_high_risk_entry_requires_response_colors"}
 return {}

func _initialize():call_deferred("run")
func save(path: String,data: Variant):
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var f=FileAccess.open(path,FileAccess.WRITE)
 if f==null:report.failures.append("Cannot write "+path);return
 f.store_string(JSON.stringify(data,"  "));f.close()
func check(ok: bool,message: String):
 report.checks+=1
 if not ok:report.failures.append(message);push_error(message)

func reviewed_sources() -> Dictionary:
 var found={}
 for directory in ["res://work/ai-training/recent-2026-09-27/annotations","res://work/ai-training/frog-cloud-2026-09-27/annotations"]:
  for file in DirAccess.get_files_at(directory):
   if not file.ends_with(".training.json"):continue
   var path=directory.path_join(file);var doc=Training.normalize_json(JSON.parse_string(FileAccess.get_file_as_string(path)))
   if not doc is Dictionary:continue
   var rows=doc.annotations.filter(func(r):return "actual_trajectory_snapshot" not in r.get("tags",[]))
   found[doc.replay.sha256]={"rows":rows,"path":path,"sha256":FileAccess.get_sha256(path)}
 return found

func known(e,who: int) -> bool:return e.players[who].hand.all(func(c):return c.card_id!="back" and not c.get("ai_unknown",false))
func same_operation(a: Dictionary,b: Dictionary) -> bool:
 var left=a.duplicate(true);var right=b.duplicate(true);left.erase("payment");right.erase("payment")
 return Actions.canonical(left)==Actions.canonical(right)

func row_at(training,index: int,seat: int,winner: int) -> Dictionary:
 var packet=training.archive.frame(index);var e=training.restore(index)
 return {"group":training.replay_hash,"frame_index":index,"seat":seat,"game_id":packet.game_id,"turn":e.turn,"sequence":packet.sequence,
  "observation":Observation.build(e,seat),"features":Value.strategic_features(e,seat),"own_hand_known":known(e,seat),"feature_schema":Value.Strategic.SCHEMA,
  "status":"terminal" if winner!=-2 else "unfinished","outcome":1 if winner==seat else -1 if winner==1-seat else 0 if winner==-1 else null,
  "decision_point_verified":packet.projection.get("training_context",{}).get("decision_point",false),
  "hindsight":false,"confidence":"high","teacher_action":{},"comparison_action":{},"tags":["actual_trajectory_snapshot"]}

func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--") and "=" in arg:
   var parts=arg.substr(2).split("=",true,1);options[parts[0]]=parts[1]
 var files=Array(DirAccess.get_files_at("res://replay")).filter(func(file):return file.ends_with(".mreply") and file>=options.since)
 files.sort();files=files.slice(maxi(0,files.size()-int(options.limit)),files.size())
 var reviewed=reviewed_sources();var behavior=[]
 var behavior_cache={}
 if options["reuse-behavior"]=="true":
  var old_manifest=JSON.parse_string(FileAccess.get_file_as_string(options.output+"/manifest.json"))
  var old_behavior=Training.normalize_json(JSON.parse_string(FileAccess.get_file_as_string(options.output+"/behavior.json")))
  if old_manifest is Dictionary and old_manifest.get("action_code_hash","")==FileAccess.get_sha256("res://scripts/ai/algorithm_actions.gd") and old_behavior is Dictionary:
   for record in old_behavior.records:behavior_cache[str(record.group)+":"+str(record.frame_index)]=record
 report.extraction_hash=FileAccess.get_sha256("res://tools/ai/replay_dataset.gd")
 report.feature_code_hash=FileAccess.get_sha256("res://scripts/ai/strategic_features.gd")
 report.action_code_hash=FileAccess.get_sha256("res://scripts/ai/algorithm_actions.gd")
 for file in files:
  var path="res://replay/"+file;var hash_before=FileAccess.get_sha256(path);var loaded=Archive.read(path)
  if loaded.has("error"):report.excluded.append({"file":file,"reason":loaded.error});continue
  var training=Training.new();training.archive=loaded.archive;training.source_path=path;training.replay_hash=hash_before
  var terminals={};var first={};var last={};var indices={};var clean_frames=[]
  var profiles={}
  for index in range(loaded.archive.frames.size()):
   var packet=loaded.archive.frame(index);var raw=packet.projection.state
   if raw.winner!=-2:terminals[packet.game_id]=int(raw.winner)
   if index==0:
    profiles={"leaders":raw.players.map(func(p):return p.leader.card_id),"recorded_rules_hash":loaded.archive.metadata.get("rules","")}
   if raw.winner!=-2 or raw.phase!="main" or raw.priority!=raw.active or not raw.stack.is_empty() or not raw.combat.is_empty():continue
   var key=packet.game_id+":"+str(raw.turn)
   if not first.has(key):first[key]=index
   last[key]=index
   if packet.projection.get("training_context",{}).get("decision_point",false):clean_frames.append(index)
  for key in first:indices[first[key]]=true;indices[last[key]]=true
  var labels=reviewed.get(hash_before,{"rows":[]});var rows={}
  for label in labels.rows:indices[int(label.frame_index)]=true
  var sorted_indices=indices.keys();sorted_indices.sort()
  for index in sorted_indices:
   var packet=loaded.archive.frame(index);var winner=terminals.get(packet.game_id,-2);var e=training.restore(index)
   for seat in [0,1]:
    if not known(e,seat):report.hidden_hand_skips+=1;continue
    var row=row_at(training,index,seat,winner)
    # Only the original recorded result labels trajectory snapshots.
    check(row.observation.players[1-seat].hand.is_empty() and not row.observation.players.any(func(p):return p.has("deck")),file+": hidden information leaked")
    rows[str(index)+":"+str(seat)]=row
  for label in labels.rows:
   var key=str(label.frame_index)+":"+str(label.seat)
   if not rows.has(key):continue
   var row=rows[key];var e=training.restore(label.frame_index)
   for field in ["comment","recommended_text","confidence","hindsight","tags"]:row[field]=label.get(field,row.get(field,""))
   row.annotation_source={"kind":"reextracted_reviewed_label","file":labels.path,"sha256":labels.sha256,"original_source":label.get("annotation_source",{})}
   for field in ["teacher_action","comparison_action"]:
    if label.get(field,{}).has("action"):
     row[field]=Training.evaluate_action(e,label.seat,label[field].action,true)
     for extra in ["source","recorded_frame","recorded_sequence"]:
      if label[field].has(extra):row[field][extra]=label[field][extra]
   report.human_labels+=1
   if row.get("tags",[]).any(func(tag):return str(tag).begins_with("reserve_gungnir")) or "reserve_response_colors" in row.get("tags",[]):
    var threat=Pressure.forecast(e,label.seat)
    if not threat.risk and row.comparison_action.get("action",{}).get("card_id","") in ["169","129","spell-fdf-037"]:
     var previous_teacher=row.teacher_action;row.teacher_action=row.comparison_action;row.comparison_action=previous_teacher
     row.annotation_source.latest_user_directive="Prioritize life pressure and Castle/bats; no forced reserve without forecast high-risk entry"
     row.tags.append("user_directive_overrides_unforecast_reserve");row.confidence="medium"
   if row.teacher_action.get("endpoint_complete",false) and row.comparison_action.get("endpoint_complete",false):report.preference_pairs+=1
  # Behavior labels are only first-revision actions recorded before resolution;
  # no later-state hindsight is used to infer a recommended action.
  var behavior_count=0
  for index in clean_frames:
   var e=training.restore(index);var seat=e.active
   if not known(e,seat):continue
   var cache_key=hash_before+":"+str(index)
   if behavior_cache.has(cache_key):
    var record=behavior_cache[cache_key].duplicate(true);record.features=Value.strategic_features(e,seat)
    behavior.append(record);behavior_count+=1
    if record.menu_truncated:report.truncated_menus+=1
    var turn_key=loaded.archive.frame(index).game_id+":"+str(e.turn)
    if first.get(turn_key,-1)==index:add_pressure_label(training,rows,index,seat,terminals.get(loaded.archive.frame(index).game_id,-2),e,{"actions":record.legal_actions,"truncated":record.menu_truncated})
    continue
   var actual=training.recorded_action(index,seat,e)
   if actual.is_empty():continue
   var env=Env.new();env.setup(e);var menu=env.legal_actions();var matches=[]
   for entry in menu.actions:
    if same_operation(entry.action,actual.action):matches.append(entry.id)
   if matches.is_empty():report.rejected_actions+=1;continue
   if menu.truncated:report.truncated_menus+=1
   var record={"group":hash_before,"frame_index":index,"seat":seat,"game_id":loaded.archive.frame(index).game_id,"turn":e.turn,"features":Value.strategic_features(e,seat),
    "legal_actions":menu.actions,"menu_truncated":menu.truncated,"unsupported":menu.unsupported,"acceptable_action_ids":matches,"actual_action":actual.action,
    "payment_supervision":false,"source":"replay_first_revision","recorded_frame":actual.frame_index,"recorded_sequence":actual.sequence}
   behavior.append(record);behavior_count+=1
   var turn_key=loaded.archive.frame(index).game_id+":"+str(e.turn)
   if first.get(turn_key,-1)==index:add_pressure_label(training,rows,index,seat,terminals.get(loaded.archive.frame(index).game_id,-2),e,menu)
  var doc={"schema":Training.SCHEMA,"feature_schema":Value.Strategic.SCHEMA,"replay":{"file":file,"sha256":hash_before,"rules_hash":loaded.archive.metadata.get("rules","")},"annotations":rows.values()}
  var output=options.output+"/annotations/"+file.get_basename()+"_"+hash_before.left(12)+".training.json"
  save(output,doc)
  check(FileAccess.get_sha256(path)==hash_before,file+": original replay changed")
  if labels.has("path"):check(FileAccess.get_sha256(labels.path)==labels.sha256,file+": human source changed")
  report.samples+=rows.size();report.behaviors+=behavior_count
  report.replays.append({"file":file,"sha256":hash_before,"frames":loaded.archive.frames.size(),"clean_decisions":clean_frames.size(),"samples":rows.size(),"behaviors":behavior_count,"games":terminals,"profiles":profiles,"annotation_file":output})
  print("REPLAY ",file," samples=",rows.size()," behavior=",behavior_count," winners=",terminals)
  save(options.output+"/manifest.json",report)
 save(options.output+"/behavior.json",{"schema":"multicolor.ai.behavior.v1","feature_schema":Value.Strategic.SCHEMA,"records":behavior,"payment_supervision":false,"policy_scope":"main decisions with engine responses"})
 save(options.output+"/manifest.json",report)
 print("CORPUS samples=",report.samples," behaviors=",report.behaviors," human=",report.human_labels," pairs=",report.preference_pairs," failures=",report.failures.size())
 quit(0 if report.failures.is_empty() else 1)

func add_pressure_label(training,rows: Dictionary,index: int,seat: int,winner: int,e,menu: Dictionary):
 var key=str(index)+":"+str(seat)
 if rows.has(key) and not rows[key].teacher_action.is_empty():return
 var pair=pressure_pair(e,seat,menu)
 if pair.is_empty():return
 var row=rows.get(key,row_at(training,index,seat,winner))
 row.teacher_action=pair.teacher;row.comparison_action=pair.comparison;row.confidence="medium"
 row.tags=["user_pressure_objective_pair"]
 row.annotation_source={"kind":"user_directed_weak_teacher","objective":"active life pressure, Castle/bat routes; conditional Gungnir reserve","reason":pair.reason,"public_entry_risk":pair.risk,"objective_margin":pair.margin,"menu_truncated":menu.truncated,"terminal_label_policy":"original recorded result only; no hypothetical wins"}
 rows[key]=row;report.preference_pairs+=1
