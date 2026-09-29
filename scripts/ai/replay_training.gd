extends RefCounted
## Sidecar annotations never change the archive. Only seat observations are exported.
const SCHEMA="multicolor.ai.human_annotations.v1"
const Paths=preload("res://scripts/portable_paths.gd")
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Observation=preload("res://scripts/ai/observation.gd")
const State=preload("res://scripts/ai/simulation_state.gd")
const Action=preload("res://scripts/ai/action.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
const Round=preload("res://scripts/ai/public_round.gd")
var archive
var source_path=""
var replay_hash=""
var output_path=""
var annotations=[]
var load_error=""

func setup(data,path: String=""):
 archive=data;source_path=path
 if not path.is_empty():replay_hash=FileAccess.get_sha256(path)
 if replay_hash.is_empty():
  var context=HashingContext.new();context.start(HashingContext.HASH_SHA256)
  for frame in archive.frames:context.update(frame.bytes)
  replay_hash=context.finish().hex_encode()
 var stem="replay" if path.is_empty() else path.get_file().get_basename().validate_filename()
 output_path=Paths.root().path_join("training").path_join(stem+"_"+replay_hash.left(12)+".training.json")
 if not FileAccess.file_exists(output_path):return
 var saved=normalize_json(JSON.parse_string(FileAccess.get_file_as_string(output_path)))
 if not saved is Dictionary or saved.get("schema")!=SCHEMA or not saved.get("replay") is Dictionary or saved.replay.get("sha256")!=replay_hash or not saved.get("annotations") is Array:
  load_error="训练标注文件无效，请先移走该文件再重新标注：\n"+output_path;return
 for row in saved.annotations:
  if not row is Dictionary or not row.get("frame_index") is int or row.frame_index<0 or row.frame_index>=archive.frames.size() or row.get("seat") not in [0,1]:
   load_error="训练标注包含无效步骤或座位：\n"+output_path;return
  if not row.get("comment","") is String or not row.get("recommended_text","") is String or not row.get("teacher_action",{}) is Dictionary or not row.get("comparison_action",{}) is Dictionary or row.get("confidence","high") not in ["high","medium","low"]:
   load_error="训练标注字段损坏：\n"+output_path;return
 annotations=saved.annotations

static func normalize_json(value: Variant) -> Variant:
 # Godot JSON numbers are floats; normalize integral IDs for Dictionary equality.
 if value is float and is_finite(value) and value==floor(value):return int(value)
 if value is Dictionary:
  for key in value:value[key]=normalize_json(value[key])
 elif value is Array:
  for i in range(value.size()):value[i]=normalize_json(value[i])
 return value

func find(index: int,seat: int) -> Dictionary:
 for row in annotations:
  if int(row.frame_index)==index and int(row.seat)==seat:return row.duplicate(true)
 return {}

func restore(index: int):
 var packet=archive.frame(index);var raw=packet.projection.state
 var e=Duel.new()
 for key in raw:
  if key not in ["players","pending","forced_cast","presentation_events"]:e.set(key,raw[key].duplicate(true) if raw[key] is Array or raw[key] is Dictionary else raw[key])
 e.players=raw.players.duplicate(true);e.cards.merge(archive.definitions,true)
 for p in e.players:
  for c in p.field+p.hand+p.palette+p.grave+p.exile:
   if c.uid==p.leader.uid:p.leader=c
   for j in range(p.get("extra_leaders",[]).size()):
    if c.uid==p.extra_leaders[j].uid:p.extra_leaders[j]=c
 e.next_uid=1000000;e.next_stack=1000000;e.recorded_life=e.players.map(func(p):return p.life)
 # Public replays omit private RNG state. Use a reproducible synthetic scenario,
 # independent of hidden cards and the recording's actual future coin outcomes.
 e.rng.seed=maxi(0,int(packet.sequence))+1
 e.ai_memory=[{},{}];e.log=[];e.history=[];e.presentation_events=[]
 return e

func context(index: int,seat: int) -> Dictionary:
 var packet=archive.frame(index)
 var e=restore(index)
 var own_known=e.players[seat].hand.all(func(c):return c.card_id!="back")
 # An old frame cannot prove that a private choice was not stripped by the recorder.
 var clean=packet.projection.get("training_context",{}).get("decision_point",false)
 var available=clean and own_known and e.winner==-2 and e.phase=="main" and e.active==seat and e.priority==seat and e.stack.is_empty() and e.combat.is_empty()
 var info="可选择下一步推荐招法；支付和后续选择按公开启发式推演。" if available else "此步骤可写点评与推荐路线；未记录完整主阶段决策状态，暂不生成已验证招法。"
 if not available and e.winner==-2:
  info+="\n评价电脑走法时，请选择电脑方并退到操作发生前的主阶段。"
 var result={"observation":Observation.build(e,seat),"features":snapshot_features(packet,seat),"choices":[],"computer_choice":{},"decision_available":available,"info":info,"own_hand_known":own_known}
 if not available:return result
 var sim=State.fork(e,seat)
 result.info+="\n随机效果只代表一种固定的假设情景，实际结果可能不同。"
 var target_policy=AI.spell_target if sim.players[seat].leader.card_id==AI.REMILIA else Round.opponent_target
 var actions=Action.main_candidates(sim,seat,target_policy,24)
 for action in actions:
  var choice=evaluate_action(sim,seat,action)
  if not choice.is_empty():result.choices.append(choice)
 var recorded=recorded_action(index,seat,e)
 if not recorded.is_empty():
  var choice=evaluate_action(sim,seat,recorded.action)
  if not choice.is_empty():
   choice.source="replay_actual";choice.recorded_frame=recorded.frame_index;choice.recorded_sequence=recorded.sequence
   result.computer_choice=choice
   result.info+="\n较差对照可直接选择录像中此评价方的实际操作。"
 else:result.info+="\n下一步没有可识别的实际操作，可手选对照或只记文字。"
 return result

static func evaluate_action(e,seat: int,action: Dictionary,extended: bool=false) -> Dictionary:
 var test=State.fork(e,seat)
 if not Action.apply(test,seat,action):return {}
 var complete=AI.settle_sim(test,seat)
 # The replay's actual future draw must not leak into a counterfactual endpoint.
 if test.players[seat].hand.any(func(c):return c.get("ai_unknown",false)):complete=false
 var f={}
 if complete:f=Value.strategic_features(test,seat) if extended else Value.features(test,seat)
 var result={"action":action.duplicate(true),"label":action_label(e,action),"features":f,"endpoint_complete":complete,"endpoint_policy":"public_heuristic_v1","rng_policy":"public_sequence_seed_v1","rng_seed":e.rng.seed}
 if extended:result.winner=test.winner
 return result

func recorded_action(index: int,seat: int,e) -> Dictionary:
 var packet=archive.frame(index)
 # Only inspect the first later revision. Never borrow an opponent's action,
 # a later turn or a different game to fill a missing recording.
 for next_index in range(index+1,mini(index+9,archive.frames.size())):
  var following=archive.frame(next_index)
  if following.game_id!=packet.game_id:return {}
  if following.sequence==packet.sequence:continue
  var raw=following.projection.state
  if raw.turn!=e.turn or raw.active!=seat:return {}
  var action={}
  if not raw.combat.is_empty() and raw.combat.get("owner",-1)==seat and raw.combat.get("step","")=="attack_window":
   action={"kind":"attack","uid":raw.combat.attacker.uid}
   if raw.combat.get("direct",false) and raw.combat.blockers.size()==1:action.target=raw.combat.blockers[0].duplicate(true)
  elif raw.stack.size()==1:
   var entry=raw.stack[0]
   if entry.get("kind","")=="card" and entry.get("owner",-1)==seat:
    var c=e.find_card(int(entry.card.uid))
    if not c.is_empty() and c.owner==seat and c.card_id==entry.card.card_id:
     action={"kind":"cast","uid":c.uid,"card_id":c.card_id,"target":entry.target.duplicate(true)}
  elif raw.stack.is_empty() and raw.combat.is_empty():
   var probe=State.fork(e,seat)
   # A public state transition confirms pass; an empty stack alone could also
   # be surrender, an activation or a recording gap.
   if Action.apply(probe,seat,{"kind":"pass"}) and pass_signature(probe,seat)==pass_signature(restore(next_index),seat):action={"kind":"pass"}
  if action.is_empty():return {}
  var probe=State.fork(e,seat)
  if not Action.apply(probe,seat,action):return {}
  return {"action":action,"frame_index":next_index,"sequence":following.sequence}
 return {}

static func pass_signature(e,seat: int) -> Dictionary:
 var result=Observation.build(e,seat)
 result.erase("pending");result.passes=e.passes
 return result

static func snapshot_features(packet: Dictionary,seat: int) -> Dictionary:
 var raw=packet.projection.state;var queries=packet.projection.queries
 var own=raw.players[seat];var other=raw.players[1-seat]
 var f={"life_margin":float(own.life-other.life),"board_margin":0.0,"hand_margin":float(own.hand.size()-other.hand.size()),"role_ready":0.0,"color_sources":0.0,"ready_damage":0.0,"incoming_damage":0.0,"fragile_units":0.0,"mana":0.0}
 var e=Duel.new();e.cards.merge(packet.projection.definitions,true);e.players=raw.players.duplicate(true)
 for key in ["turn","active","phase","turn_usage"]:e.set(key,raw[key])
 var colors=[]
 for who in range(2):
  for c in raw.players[who].field:
   var id=c.card_id
   if not e.cards.has(id):continue
   if e.is_unit(c):
    var stats=queries.get("stats",{}).get(c.uid,queries.get("stats",{}).get(str(c.uid),{}))
    var power=int(stats.get("power",0));var health=maxi(0,int(stats.get("health",0))-c.damage);var spirit=maxi(0,int(stats.get("spirit",0)))
    f.board_margin+=(maxi(0,power)+health+spirit)*(1 if who==seat else -1)
    if who==seat:
     if health<=1:f.fragile_units+=1
     if c.uid==own.leader.uid:f.role_ready=1
    var sick=queries.get("sick",{}).get(c.uid,queries.get("sick",{}).get(str(c.uid),true))
    if not c.tapped and not sick:
     if who==seat:f.ready_damage+=spirit
     else:f.incoming_damage+=spirit
   if who==seat and e.cards[id].kind!="符卡":
    for color in e.Pack.colors(e,c):
     if color not in colors:colors.append(color)
 var requirements=e.cards[own.leader.card_id].colors
 f.color_sources=1.0 if requirements.all(func(color):return color in colors) else 0.0
 f.mana=float(e.source_resources(seat).size())
 return f

static func action_label(e,a: Dictionary) -> String:
 if a.kind=="pass":return "过牌 / 保留费用"
 var c=e.find_card(int(a.get("uid",-1)))
 var label=("使用 " if a.kind=="cast" else "攻击：")+e.cards[c.card_id].name+" [#"+str(c.uid)+"]"
 var t=a.get("target",{})
 if t.has("uid"):
  var target=e.find_card(int(t.uid))
  if not target.is_empty():label+=" → "+e.cards[target.card_id].name+" [#"+str(target.uid)+"]"
 elif t.has("player"):label+=" → "+e.player_names[int(t.player)]
 if t.has("mode"):label+=" / "+str(t.mode)
 if t.has("sacrifice"):
  var cost=e.find_card(int(t.sacrifice.get("uid",-1)))
  if not cost.is_empty():label+=" / 牺牲 "+e.cards[cost.card_id].name+" [#"+str(cost.uid)+"]"
 if t.has("extra"):label+=" / 额外抓 %d 张"%int(t.extra)
 return label

func put(index: int,seat: int,fields: Dictionary,ctx: Dictionary) -> Dictionary:
 if not load_error.is_empty():return {"error":load_error}
 var packet=archive.frame(index)
 var row={"frame_index":index,"step":index+1,"game_id":packet.game_id,"sequence":packet.sequence,"round":archive.frames[index].round,"turn":archive.frames[index].turn,"seat":seat,"group":replay_hash,"observation":ctx.observation,"features":ctx.features,"own_hand_known":ctx.own_hand_known,"feature_schema":Value.SCHEMA,"updated":Time.get_datetime_string_from_system()}
 row.merge(fields,true)
 var winner=-2
 for i in range(index,archive.frames.size()):
  var frame=archive.frame(i)
  if frame.game_id!=packet.game_id:break
  if frame.projection.state.winner!=-2:winner=int(frame.projection.state.winner);break
 row.outcome=1 if winner==seat else -1 if winner==1-seat else 0 if winner==-1 else null
 row.status="terminal" if winner!=-2 else "unfinished"
 # Keep actual result separate from the counterfactual teacher action.
 var replaced=false
 for i in range(annotations.size()):
  if int(annotations[i].frame_index)==index and int(annotations[i].seat)==seat:annotations[i]=row;replaced=true;break
 if not replaced:annotations.append(row)
 return save()

func remove(index: int,seat: int) -> Dictionary:
 if not load_error.is_empty():return {"error":load_error}
 annotations=annotations.filter(func(row):return int(row.frame_index)!=index or int(row.seat)!=seat)
 return save()

func save() -> Dictionary:
 if not load_error.is_empty():return {"error":load_error}
 var data={"schema":SCHEMA,"replay":{"file":source_path.get_file(),"sha256":replay_hash,"rules_hash":archive.metadata.get("rules",""),"export_game_version":ProjectSettings.get_setting("application/config/version")},"information":"own hand and public zones only; opposing reveal memory unavailable in replay","annotations":annotations}
 var error=DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
 if error!=OK:return {"error":"无法创建训练文件夹："+error_string(error)}
 var f=FileAccess.open(output_path+".tmp",FileAccess.WRITE)
 if f==null:return {"error":"无法写入训练文件：\n"+output_path}
 f.store_string(JSON.stringify(data,"  "));f.flush();error=f.get_error();f.close()
 if error!=OK:return {"error":"训练文件写入未完成："+error_string(error)}
 error=DirAccess.rename_absolute(output_path+".tmp",output_path)
 if error!=OK:return {"error":"无法保存训练文件："+error_string(error)}
 return {"path":output_path,"annotations":annotations.size()}
