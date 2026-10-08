extends RefCounted
## Separate setup, recording and replay timelines; applying is the only document edit.
const Adapter=preload("res://scripts/tutorial/game_adapter.gd")
const Config=preload("res://scripts/tutorial/config.gd")
const Sequence=preload("res://scripts/tutorial/sequence.gd")
const Commands=preload("res://scripts/tutorial/battle_commands.gd")
const Codec=preload("res://net/state_codec.gd")
const ZONE_NAMES={"deck":"牌库","hand":"手牌","field":"战场","palette":"颜色盘","grave":"墓地","exile":"除外","leader":"自机区","stack":"堆叠"}
signal changed
signal rejected(reason: String)
var adapter=Adapter.new()
var scene: Dictionary={}
var definitions: Dictionary={}
var actions: Array=[]
var random_results: Array=[]
var points: Array=[]
var recording=false
var replaying=false
var ready_units=true
var setup_unit_states: Dictionary={}
var replay=Sequence.new()
var final_facts: Dictionary={}
var cursor=0 # Number of completed actions; this is also the next action to replace.
var advance_rng=true
var replay_origin=0

func configure(value: Dictionary,cards: Dictionary) -> String:
 scene=value.duplicate(true);definitions=cards
 assign_aliases(scene)
 var reason=adapter.load_scenario("recording",scene,definitions)
 if not reason.is_empty():return reason
 bind();remember_setup_unit_states()
 return ""

func remember_setup_unit_states():
 setup_unit_states.clear()
 for p in scene.players:
  var entries=p.get("field",[]).duplicate()
  if Config.leader_zone(p)=="field":entries.append(p.leader)
  entries.append_array(p.get("extra_leaders",[]).filter(func(entry):return entry.get("zone","leader")=="field"))
  for entry in entries:
   var state=entry.get("state",{});var card=adapter.entity(entry.alias)
   if not card.is_empty() and adapter.engine.is_unit(card) and (state.has("entered") or state.has("entered_turns")):setup_unit_states[int(card.uid)]=true

static func assign_aliases(value: Dictionary):
 var used={}
 for p in value.players:
  for zone in ["leader","extra_leaders","deck_order","hand","field","palette","grave","exile"]:
   for card in [p.leader] if zone=="leader" else p.get(zone,[]):
    if card.has("alias"):used[card.alias]=true
 var index=1
 for p in value.players:
  for zone in ["leader","extra_leaders","deck_order","hand","field","palette","grave","exile"]:
   for card in [p.leader] if zone=="leader" else p.get(zone,[]):
    if card.has("alias"):continue
    while used.has("recorded_"+str(index)):index+=1
    card.alias="recorded_"+str(index);used[card.alias]=true;index+=1

func bind():
 var e=adapter.engine
 e.debug_enabled=true;e.debug_free_payment=false;e.command_filter=authorize
 e.record_random_without_advance=recording and not advance_rng
 e.paid_cast_uid=-1
 if not e.command_accepted.is_connected(accepted):e.command_accepted.connect(accepted)
 if not e.random_observed.is_connected(randomized):e.random_observed.connect(randomized)

func editing_setup() -> bool:
 return not recording and not replaying and points.is_empty() and actions.is_empty()

func remove_setup_hand_card(uid: int) -> bool:
 var card=adapter.engine.find_card(uid) if adapter.engine!=null else {}
 return remove_setup_card(uid) if card.get("zone")=="hand" else false

func can_edit_setup() -> bool:
 if not editing_setup():return false
 var e=adapter.engine
 return e!=null and e.debug_enabled and e.winner==-2 and e.pending.is_empty() and e.stack.is_empty() and e.combat.is_empty()

func remove_setup_card(uid: int) -> bool:
 if not can_edit_setup():return false
 var e=adapter.engine
 var card=e.find_card(uid)
 if card.is_empty() or card.zone not in Config.ZONES+["leader"] or is_same(card,e.players[card.owner].leader):return false
 # Remove only this instance from the private tableau, without discard events.
 e.detach(card);e.players[card.owner].get("extra_leaders",[]).erase(card)
 card.zone="void";card.epoch+=1
 for alias in adapter.aliases.keys():
  if int(adapter.aliases[alias])==uid:adapter.aliases.erase(alias)
 setup_unit_states.erase(uid)
 e.note("布置删除："+e.player_names[card.owner]+" · "+e.cards[card.card_id].name)
 changed.emit()
 return true

func copy_setup_card(uid: int) -> int:
 if not can_edit_setup():return 0
 var e=adapter.engine;var card=e.find_card(uid)
 if card.is_empty() or card.zone not in Config.ZONES+["leader"]:return 0
 # Preserve the configured state, while giving the copy its own identity/alias.
 var copy=e.make_card(card.card_id,card.owner,card.zone,card.zone=="leader")
 for key in Config.CARD_FLAGS+Config.CARD_COUNTS+Config.CARD_COLOR_LISTS:
  if card.has(key):copy[key]=card[key].duplicate() if card[key] is Array else card[key]
 if setup_unit_states.has(uid):setup_unit_states[int(copy.uid)]=true
 if card.zone=="leader":
  if not e.players[card.owner].has("extra_leaders"):e.players[card.owner].extra_leaders=[]
  e.players[card.owner].extra_leaders.append(copy)
 else:
  var cards=e.players[card.owner][card.zone];cards.insert(cards.find(card)+1,copy)
 e.note("布置复制："+e.player_names[card.owner]+" · "+e.cards[card.card_id].name)
 changed.emit()
 return int(copy.uid)

func toggle_setup_unit_ready(uid: int) -> bool:
 if not can_edit_setup():return false
 var e=adapter.engine;var card=e.find_card(uid)
 if card.is_empty() or card.zone!="field" or not e.is_unit(card):return false
 # Toggle the entry age itself; haste may allow action even for a fresh unit.
 var ready=int(card.entered_turns)<int(e.players[card.owner].turns) if card.has("entered_turns") else int(card.entered)<int(e.turn)
 if not ready and int(e.players[card.owner].turns)<1:return false
 card.entered=int(e.turn) if ready else maxi(0,int(e.turn)-1)
 card.entered_turns=int(e.players[card.owner].turns) if ready else maxi(0,int(e.players[card.owner].turns)-1)
 setup_unit_states[uid]=true
 e.note("布置单位："+e.player_names[card.owner]+" · "+e.cards[card.card_id].name+(" · 未过一回合" if ready else " · 已过一回合"))
 changed.emit()
 return true

func set_setup_life(who: int,value: int) -> bool:
 if not can_edit_setup() or who not in [0,1] or value<1:return false
 var e=adapter.engine
 if int(e.players[who].life)==value:return true
 e.players[who].life=value;e.recorded_life[who]=value
 e.note("布置初始血量："+e.player_names[who]+" · "+str(value))
 changed.emit()
 return true

func authorize(seat: int,command: Dictionary) -> bool:
 if replaying:return true
 if not recording:rejected.emit("当前正在回溯既定流程，请点击“从此步重录”再进行操作。" if not points.is_empty() else "请先布置局面并点击“开始录制”。");return false
 if actions.size()>=600:rejected.emit("本段已录制 600 个动作，请结束并生成步骤。");return false
 var value=Commands.encode(adapter,seat,command)
 var check=Config.new();check.definitions=definitions;check.sequence_action(value,"recorded_action")
 if not check.errors.is_empty():rejected.emit("\n".join(check.errors));return false
 return true

func randomized(kind: String,value: int):
 if recording:random_results.append({"type":kind,"value":value})

func accepted(_seat: int,_command: Dictionary,value: Dictionary):
 if not recording:return
 actions.append(value.duplicate(true))
 points.append({"adapter":adapter.capture(),"random_count":random_results.size()})
 cursor=actions.size()
 changed.emit()

func card_entry(card: Dictionary) -> Dictionary:
 var entry={"card_id":card.card_id,"state":{}}
 for alias in adapter.aliases:
  if int(adapter.aliases[alias])==int(card.uid):entry.alias=alias;break
 for key in Config.CARD_FLAGS+Config.CARD_COUNTS+Config.CARD_COLOR_LISTS:
  if card.has(key):entry.state[key]=card[key].duplicate() if card[key] is Array else card[key]
 if str(card.card_id).begins_with("roster_token_frog"):
  entry.card_id="roster_token_frog";entry.token_name=adapter.engine.cards[card.card_id].name
  entry.token_value=int(adapter.engine.cards[card.card_id].health);entry.token_spirit=int(adapter.engine.cards[card.card_id].spirit)
 # Individually configured ages take precedence over the setup-wide default.
 var e=adapter.engine
 if card.zone=="field" and e.is_unit(card) and ready_units and not setup_unit_states.has(int(card.uid)):
  entry.state.entered=maxi(0,e.turn-1);entry.state.entered_turns=maxi(0,int(e.players[card.owner].turns)-1)
 return entry

func tableau() -> Dictionary:
 var value=scene.duplicate(true);var e=adapter.engine
 for key in ["first","turn","active","priority","phase"]:value[key]=e.get(key)
 for who in range(2):
  var p=e.players[who];var source=value.players[who]
  source.life=int(p.life);source.name=e.player_names[who];source.state={}
  for key in Config.PLAYER_FLAGS+Config.PLAYER_COUNTS:source.state[key]=p[key]
  source.leader=card_entry(p.leader);source.leader_zone=p.leader.zone
  source.erase("leader_on_field")
  source.extra_leaders=[]
  for card in p.get("extra_leaders",[]):
   var entry=card_entry(card);entry.zone=card.zone
   source.extra_leaders.append(entry)
  for zone in Config.ZONES:
   source["deck_order" if zone=="deck" else zone]=[]
   for card in p[zone]:
    if is_same(card,p.leader):continue
    # Extra leaders are stored separately to preserve their leader identity.
    if card in p.get("extra_leaders",[]):continue
    var entry=card_entry(card)
    source["deck_order" if zone=="deck" else zone].append(entry)
 assign_aliases(value)
 return value

func begin_record() -> String:
 if recording:return ""
 var value=tableau();var check=Config.new();check.definitions=definitions;check.scenario(value,"recording",{})
 if not check.errors.is_empty():return "\n".join(check.errors)
 var reason=adapter.load_scenario("recording",value,definitions)
 if not reason.is_empty():return reason
 scene=value;actions=[];random_results=[];final_facts={};bind();remember_setup_unit_states()
 points=[{"adapter":adapter.capture(),"random_count":0}]
 cursor=0;advance_rng=true;recording=true;replaying=false;changed.emit()
 return ""

func load_sequence(config: Dictionary) -> String:
 # Reconstruct every boundary with the real engine, without editing the course.
 var check=Config.new();check.definitions=definitions;check.sequence(config,"sequence",config.has("student"))
 if not check.errors.is_empty():return "\n".join(check.errors)
 var candidate=Adapter.new();var reason=candidate.load_scenario("recording",scene,definitions)
 if not reason.is_empty():return reason
 var timeline=[{"adapter":candidate.capture(),"random_count":0}]
 var playback=Sequence.new();playback.start(candidate,config)
 var limit=config.actions.size()*8+80
 for action in config.actions:
  if action.type=="delay":limit+=ceili(action.seconds)
 for i in range(limit):
  var previous=playback.index
  reason=playback.tick(candidate,config,1.0,false)
  if not reason.is_empty():return reason
  if playback.index!=previous:
   timeline.append({"adapter":candidate.capture(),"random_count":candidate.engine.random_cursor})
  if not playback.playing:break
 if playback.playing:return "序列没有完成。"
 actions=config.actions.duplicate(true);random_results=config.get("random_results",[]).duplicate(true)
 advance_rng=config.get("advance_rng",false);points=timeline
 final_facts=facts(candidate.engine);recording=false;replaying=false
 seek(0);return ""

func seek(index: int) -> bool:
 if index<0 or index>=points.size():return false
 recording=false;replaying=false;replay.playing=false;cursor=index
 adapter.restore(points[index].adapter);adapter.engine.scripted_random=false;bind();changed.emit();return true

func resume_record(index: int=-1) -> bool:
 if index<0:index=cursor
 if not seek(index):return false
 actions.resize(index);points.resize(index+1);random_results.resize(points[index].random_count)
 final_facts={};recording=true;bind();changed.emit();return true

func undo() -> bool:
 if replaying or actions.is_empty() or cursor==0:return false
 return resume_record(maxi(0,cursor-1))

func reset_setup():
 if replaying or points.is_empty():return
 adapter.restore(points[0].adapter);bind()
 recording=false;actions=[];random_results=[];points=[];final_facts={};cursor=0
 changed.emit()

func finish():
 recording=false;replaying=false
 if not points.is_empty() and cursor!=actions.size():adapter.restore(points.back().adapter);adapter.engine.scripted_random=false;bind()
 cursor=actions.size()
 final_facts=facts(adapter.engine);changed.emit()

func sequence_config() -> Dictionary:
 return {"actions":actions.duplicate(true),"random_results":random_results.duplicate(true),"advance_rng":advance_rng}

static func facts(e) -> Dictionary:
 var graph=Codec.capture(e);var state=Codec.decode(graph)
 for key in ["command_depth","debug_enabled","debug_free_payment","record_random_without_advance","scripted_random","random_results","random_cursor","random_error","advance_random_rng","revision","reveal_serial","paid_cast_uid"]:state.erase(key)
 state.definitions=graph.definitions
 return state

func verify(config: Dictionary={}) -> String:
 if actions.is_empty():return "请先录制至少一个动作。"
 var value=sequence_config() if config.is_empty() else config
 var candidate=Adapter.new();var reason=candidate.load_scenario("verify",scene,definitions)
 if not reason.is_empty():return reason
 var playback=Sequence.new();playback.start(candidate,value)
 var limit=value.actions.size()*8+80
 for action in value.actions:
  if action.type=="delay":limit+=ceili(action.seconds)
 for i in range(limit):
  reason=playback.tick(candidate,value,1.0,false)
  if not reason.is_empty():return reason
  if not playback.playing:break
 if playback.playing:return "序列没有完成。"
 if config.is_empty() and facts(candidate.engine)!=final_facts:return "重播局面与录制结果不同，请检查目标与支付设置。"
 return ""

func start_replay() -> String:
 if recording:finish()
 var reason=verify()
 if not reason.is_empty():return reason
 if cursor>=actions.size():cursor=0
 replay_origin=cursor
 adapter.restore(points[cursor].adapter);bind();replaying=true
 replay.start(adapter,sequence_config());replay.index=cursor
 adapter.engine.random_cursor=int(points[cursor].random_count)
 changed.emit();return ""

func pause_replay():
 if replaying:seek(cursor)

func tick(delta: float,busy: bool) -> String:
 if not replaying:return ""
 var reason=replay.tick(adapter,sequence_config(),delta,busy)
 if cursor!=replay.index:cursor=replay.index;changed.emit()
 if not reason.is_empty() or not replay.playing:
  seek(replay_origin if not reason.is_empty() else actions.size())
 return reason

func entity_candidate(result: Array,ref: Dictionary,fields: Dictionary,label: String,selected: bool=false):
 var c=ref.duplicate(true);c.merge(fields)
 result.append({"label":label,"selected":selected,"condition":c})

func victory_candidates() -> Array:
 var origin=Adapter.new();origin.restore(points[0].adapter)
 var e=adapter.engine;var before=origin.engine;var result=[]
 for who in range(2):
  if e.players[who].life!=before.players[who].life:
   var op="le" if e.players[who].life<before.players[who].life else "ge"
   result.append({"label":("我方" if who==0 else "敌方")+"生命 "+("≤ " if op=="le" else "≥ ")+str(e.players[who].life),"selected":who==1 and op=="le","condition":{"type":"life","player":who,"op":op,"value":e.players[who].life}})
 for subject in adapter.card_subjects():
  var ref=subject.ref;var card=subject.card;var old=origin.resolve_card(ref)
  var subject_name="生成实例 #"+str(int(ref.created)) if ref.has("created") else str(ref.alias)
  var name=e.cards[card.card_id].name+" ["+subject_name+"]"
  if card.zone!=old.get("zone",""):entity_candidate(result,ref,{"type":"entity_zone","zone":card.zone},name+" 位于 "+ZONE_NAMES.get(card.zone,card.zone),not old.is_empty() and int(old.owner)==1 and card.zone in ["grave","exile"])
  for key in Config.CARD_FLAGS:
   if old.is_empty() or card.get(key,false)!=old.get(key,false):entity_candidate(result,ref,{"type":"entity_state","key":key,"value":card.get(key,false)},name+" · "+("横置" if key=="tapped" else "已攻击")+"："+("是" if card.get(key,false) else "否"))
  for key in ["damage","timer","plus_counters","minus_counters","poverty","leader_counters","courage"]:
   if card.get(key,0)!=old.get(key,0):
    var op="ge" if card.get(key,0)>old.get(key,0) else "le"
    var labels={"damage":"已受伤害","timer":"时间指示物","plus_counters":"＋指示物","minus_counters":"－指示物","poverty":"贫穷指示物","leader_counters":"自机指示物","courage":"英勇"}
    entity_candidate(result,ref,{"type":"entity_count","key":key,"op":op,"value":card.get(key,0)},name+" · "+labels[key]+(" ≥ " if op=="ge" else " ≤ ")+str(card.get(key,0)))
  for color in ["红","蓝","绿","黄","黑"]:
   if (color in card.get("color_counters",[]))!=(color in old.get("color_counters",[])):
    var has_color=color in card.get("color_counters",[])
    var condition=ref.duplicate(true);condition.merge({"type":"entity_color_counter","color":color})
    result.append({"label":name+(" 有" if has_color else " 没有")+color+"色指示物","selected":false,"condition":condition if has_color else {"type":"not","condition":condition}})
 for who in range(2):
  var before_count=before.players[who].field.filter(func(card):return before.cards[card.card_id].kind=="单位").size()
  var after_count=e.players[who].field.filter(func(card):return e.cards[card.card_id].kind=="单位").size()
  if after_count!=before_count:
   var op="le" if after_count<before_count else "ge"
   result.append({"label":("我方" if who==0 else "敌方")+"战场单位数量"+(" ≤ " if op=="le" else " ≥ ")+str(after_count),"selected":false,"condition":{"type":"zone_count","player":who,"zone":"field","kind":"单位","op":op,"value":after_count}})
 if result.is_empty():result.append({"label":"敌方生命 ≤ 0（可编辑阈值）","selected":false,"condition":{"type":"life","player":1,"op":"le","value":0}})
 return result

func response_rule(trigger_index: int,first: int,last: int,generic_card: bool=true) -> Dictionary:
 var trigger=actions[trigger_index].duplicate(true);trigger.erase("payment")
 if generic_card and trigger.get("type")=="cast":
  var card=adapter.resolve_card(trigger.card)
  if definitions.has(card.get("card_id","")):trigger.card={"card_id":card.card_id}
  trigger.erase("target");trigger.erase("pay_colors")
 var replies=[]
 for i in range(first,last+1):
  if int(actions[i].get("player",-1))!=1:return {}
  replies.append(actions[i].duplicate(true))
 if replies.is_empty():return {}
 # Only random outcomes inside this action range belong to the response.
 var start=int(points[first].random_count);var end=int(points[last+1].random_count)
 return {"id":"recorded_response","event":"command_accepted","on_action":trigger,"when":{"type":"always"},"sequence":{"actions":replies,"random_results":random_results.slice(start,end),"advance_rng":true},"max_times":1}

func response_rules(generic_card: bool=true) -> Array:
 var rules=[];var i=0
 while i<actions.size():
  if actions[i].get("player")!=1:i+=1;continue
  var first=i
  while i+1<actions.size() and actions[i+1].get("player")==1:i+=1
  if first==0 or actions[first-1].get("player")!=0:i+=1;continue
  var rule=response_rule(first-1,first,i,generic_card)
  var state=Adapter.new();state.restore(points[first].adapter);var e=state.engine
  var predicates=[{"type":"phase","value":e.phase},{"type":"combat_step","value":e.combat.get("step","none")}]
  if not e.pending.is_empty():predicates.append({"type":"pending","kind":e.pending.kind,"owner":int(e.pending.owner)})
  else:predicates.append({"type":"priority","value":int(e.priority)})
  rule.id="recorded_response_"+str(rules.size()+1);rule.when={"type":"all","conditions":predicates}
  rules.append(rule);i+=1
 return rules
