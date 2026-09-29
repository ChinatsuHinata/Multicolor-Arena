extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
const Agent=preload("res://scripts/ai/decision_agent.gd")
const Observation=preload("res://scripts/ai/observation.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
const Models=preload("res://scripts/ai/matchup_models.gd")
const Matchup=preload("res://scripts/ai/matchup.gd")
var options={"seeds":"11,1001","output":"res://work/ai-training/episodes.json","max-actions":"1200","opponent":"res://deck/未命名卡组_7c906ca3ca80.mdeck","weights":"","round":"false","mode":"candidate","record-seats":"0"}
func _initialize():call_deferred("run")
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--") and "=" in arg:
   var pieces=arg.substr(2).split("=",true,1);options[pieces[0]]=pieces[1]
 var rem=JSON.parse_string(FileAccess.get_file_as_string("res://deck/未命名卡组_7c906ca3ca80.mdeck")).deck
 var opponent=JSON.parse_string(FileAccess.get_file_as_string(options.opponent)).deck
 var weights=Models.load_model(options.weights) if not options.weights.is_empty() else {}
 if not options.weights.is_empty() and weights.is_empty():push_error("Invalid value weights");quit(1);return
 if options.mode not in ["baseline","candidate"] or options["record-seats"] not in ["0","1","both"]:push_error("Unsupported mode or record-seats");quit(1);return
 var strategic=weights.get("generic",{}).get("schema","")==Value.STRATEGIC_SCHEMA or weights.has(Value.Strategic.KEYS[0])
 var provenance={"rules_hash":source_hash(["res://scripts/rules","res://cards"]),"agent_hash":source_hash(["res://scripts/ai"]),"weights_hash":FileAccess.get_file_as_string(options.weights).sha256_text() if not options.weights.is_empty() else "default","deck_hash":JSON.stringify(rem).sha256_text(),"opponent_hash":JSON.stringify(opponent).sha256_text(),"feature_schema":Value.STRATEGIC_SCHEMA if strategic else Value.SCHEMA}
 var games=[];var samples=[]
 for seed_text in options.seeds.split(","):
  var seed_value=int(seed_text)
  for first in [0,1]:
   var e=Duel.new();e.start(rem,opponent,first,seed_value)
   var rows=[];var actions=0;var stopped="action_limit";var start=Time.get_ticks_msec()
   var fallbacks=0;var decisions=0;var latency=[];var routing=Models.select(e,0,weights);routing.erase("weights")
   for i in range(int(options["max-actions"])):
    if e.winner!=-2:stopped="terminal";break
    var seat=e.pending.get("owner",e.priority)
    if e.phase=="mulligan":seat=0 if not e.players[0].mulligan_done else 1
    var before=e.revision
    var decision_point=e.phase=="main" and e.active==seat and e.pending.is_empty() and e.stack.is_empty() and e.combat.is_empty()
    if (options["record-seats"]=="both" or options["record-seats"]==str(seat)) and decision_point:
     rows.append({"episode":"%d:%d:%d"%[seed_value,first,seat],"seed":seed_value,"first":first,"seat":seat,"profile":e.ai_profiles[seat],"turn":e.turn,"matchup":Matchup.identify(e,seat),"observation":Observation.build(e,seat),"features":Value.strategic_features(e,seat) if strategic else Value.features(e,seat)})
    if seat==0 and options.mode=="candidate":
     var clock_start=Time.get_ticks_msec()
     var trace=Agent.step(e,seat,AI,weights,options.round=="true")
     if not trace.get("fallback",false):decisions+=1;latency.append(Time.get_ticks_msec()-clock_start)
     else:fallbacks+=1
    else:
     var clock_start=Time.get_ticks_msec()
     e.ai_step(seat)
     if seat==0 and decision_point:decisions+=1;latency.append(Time.get_ticks_msec()-clock_start)
    actions=i+1
    if e.revision==before and e.winner==-2:stopped="no_progress";break
   if e.winner!=-2:stopped="terminal"
   var episode={"episode":"%d:%d"%[seed_value,first],"seed":seed_value,"first":first,"winner":e.winner,"status":stopped,"actions":actions,"turn":e.turn,"life":e.players.map(func(p):return p.life),"milliseconds":Time.get_ticks_msec()-start,"decisions":decisions,"fallbacks":fallbacks,"decision_milliseconds":latency,"model_routing":routing}
   games.append(episode)
   for row in rows:
    row.status=stopped;row.outcome=1.0 if e.winner==row.seat else -1.0 if e.winner==1-row.seat else 0.0 if e.winner==-1 else null
    samples.append(row)
   print("EPISODE ",JSON.stringify(episode))
   # Checkpoint every game; incomplete games are retained, never counted as draws.
   var data={"schema":"multicolor.ai.episodes.v1","mode":options.mode,"opponent_round":options.round=="true","opponent":options.opponent,"record_seats":options["record-seats"],"games":games,"samples":samples}
   data.merge(provenance);save(data)
 print("DATASET ",options.output," games ",games.size()," samples ",samples.size())
 quit()
func save(data: Dictionary):
 DirAccess.make_dir_recursive_absolute(options.output.get_base_dir())
 var f=FileAccess.open(options.output,FileAccess.WRITE)
 if f==null:push_error("Could not write dataset");quit(1);return
 f.store_string(JSON.stringify(data));f.close()

func source_files(root: String) -> Array:
 var paths=[]
 var directory=DirAccess.open(root)
 if directory==null:return paths
 for file in directory.get_files():
  if file.get_extension() in ["gd","json"]:paths.append(root.path_join(file))
 for child in directory.get_directories():paths.append_array(source_files(root.path_join(child)))
 return paths
func source_hash(roots: Array) -> String:
 var paths=[];var hashes={}
 for root in roots:paths.append_array(source_files(root))
 paths.sort()
 for path in paths:hashes[path]=FileAccess.get_file_as_string(path).sha256_text()
 return JSON.stringify(hashes).sha256_text()
