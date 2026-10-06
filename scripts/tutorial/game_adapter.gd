extends RefCounted
## Tutorial-only setup and observation. Playing always uses the existing engine.
const Duel=preload("res://scripts/tutorial/command_duel.gd")
const Commands=preload("res://scripts/tutorial/battle_commands.gd")
const Config=preload("res://scripts/tutorial/config.gd")
const Gateway=preload("res://net/command_gateway.gd")
const Codec=preload("res://net/state_codec.gd")
signal observed(event: Dictionary)
var engine
var aliases: Dictionary={}
var components: Dictionary={}
var scenario_id=""
var opponent_config: Dictionary={}
var last_revision=-1
var last_phase=""
var last_priority=-1
var scene_type="battlefield"
var scene_config: Dictionary={}
var ui_deck: Dictionary={}
var last_ui_action: Dictionary={}
var created_origin=1

func load_scenario(id: String,s: Dictionary,cards: Dictionary) -> String:
 scene_type=s.get("type","battlefield");scene_config=s.duplicate(true);last_ui_action={}
 if scene_type!="battlefield":
  engine=null;aliases={};components=s.get("components",{}).duplicate(true);scenario_id=id;opponent_config={"strategy":"paused"}
  ui_deck=s.deck.duplicate(true);ui_deck.id="tutorial_"+id;ui_deck.main=ui_deck.get("main",[]);ui_deck.side=ui_deck.get("side",[])
  ui_deck.rule_set=ui_deck.get("rule_set",preload("res://scripts/deck_rule_set.gd").OFFICIAL)
  return ""
 # Build privately; a failed setup cannot replace the running scenario.
 ui_deck={}
 var candidate=Duel.new(cards)
 candidate.rng.seed=int(s.seed)
 candidate.first=int(s.get("first",0));candidate.turn=int(s.get("turn",1))
 candidate.active=int(s.get("active",0));candidate.priority=int(s.get("priority",0))
 candidate.phase=s.get("phase","main")
 var next_aliases={}
 for who in range(2):
  var source=s.players[who]
  var p={"life":int(source.get("life",20)),"deck":[],"hand":[],"field":[],"palette":[],"grave":[],"exile":[],"leader":{},"potato":false,"mulligan_done":true,"turns":1,"possession_count":0}
  for key in source.get("state",{}):p[key]=source.state[key] if key in Config.PLAYER_FLAGS else int(source.state[key])
  candidate.players.append(p)
  candidate.player_names[who]=source.get("name","学员" if who==0 else "教程对手")
  p.leader=create(candidate,source.leader,who,"leader",next_aliases)
  if source.get("leader_on_field",false):
   p.leader.zone="field"
   p.field.append(p.leader)
  for zone in Config.ZONES:
   var key="deck_order" if zone=="deck" else zone
   var entries=source.get(key,[]).duplicate(true)
   if zone=="field":
    for i in range(entries.size()):entries[i]["position"]=int(entries[i].get("position",i))
    entries.sort_custom(func(a,b):return a.position<b.position)
   for entry in entries:p[zone].append(create(candidate,entry,who,zone,next_aliases))
 # Preserve card-specific match initialization (e.g. the extra leader), while
 # tableau placement deliberately does not replay enter/draw triggers.
 candidate.Roster.New.start(candidate)
 for who in range(2):
  if not s.players[who].has("extra_leaders"):continue
  candidate.players[who].extra_leaders=[]
  for entry in s.players[who].extra_leaders:
   var zone=entry.get("zone","leader");var card=create(candidate,entry,who,zone,next_aliases)
   card.leader=true;candidate.players[who].extra_leaders.append(card)
   if zone!="leader":candidate.players[who][zone].append(card)
 for who in range(2):
  for c in candidate.players[who].field.duplicate():
   candidate.players[who].field.erase(c)
   var reason=candidate.field_error(c,who)
   candidate.players[who].field.append(c)
   if not reason.is_empty():return "scenarios.%s.players.%d.field · %s：%s" % [id,who,c.card_id,reason]
   if candidate.is_unit(c) and c.damage>=candidate.stat(c,"health"):return "scenarios.%s.players.%d.field：单位已受到致死伤害" % [id,who]
   if c.entered>candidate.turn or c.get("entered_turns",0)>candidate.players[who].turns:return "scenarios.%s.players.%d.field.state：入场回合不能晚于当前回合" % [id,who]
 candidate.recorded_life=candidate.players.map(func(p):return p.life)
 candidate.presentation_events.clear();candidate.history.clear();candidate.log.clear()
 candidate.note("教学局面已就绪")
 engine=candidate;aliases=next_aliases;components=s.get("components",{}).duplicate(true)
 created_origin=engine.next_uid;bind_commands()
 opponent_config=s.get("opponent",{"strategy":"paused"}).duplicate(true);scenario_id=id
 reset_observation()
 return ""

func create(e,entry: Dictionary,who: int,zone: String,bindings: Dictionary) -> Dictionary:
 var c
 if entry.card_id=="roster_token_frog":
  c=e.Roster.create_token(e,who,"frog",int(entry.token_value),["蓝","绿"],["不占战场格"],false)
  e.cards[c.card_id].spirit=int(entry.token_spirit)
  e.cards[c.card_id].name=entry.token_name
  c.zone=zone
 else:c=e.make_card(entry.card_id,who,zone,zone=="leader")
 for key in entry.get("state",{}):
  c[key]=entry.state[key].duplicate() if key in Config.CARD_COLOR_LISTS else entry.state[key] if key in Config.CARD_FLAGS else int(entry.state[key])
 if entry.has("alias"):bindings[entry.alias]=c.uid
 return c

func entity(alias: String) -> Dictionary:
 return engine.find_card(int(aliases[alias])) if engine!=null and aliases.has(alias) else {}

func resolve_card(ref: Dictionary) -> Dictionary:
 if ref.has("alias"):return entity(ref.alias)
 if ref.has("created"):return engine.find_card(created_origin+int(ref.created)) if engine!=null else {}
 return {}

func card_subjects() -> Array:
 var result=[]
 if engine==null:return result
 for alias in aliases:
  var card=entity(alias)
  if not card.is_empty():result.append({"ref":{"alias":alias},"card":card})
 for uid in range(created_origin,engine.next_uid):
  var card=engine.find_card(uid)
  if not card.is_empty():result.append({"ref":{"created":uid-created_origin},"card":card})
 return result

func bind_commands():
 engine.action_encoder=encode_command
 if not engine.command_accepted.is_connected(accepted_command):engine.command_accepted.connect(accepted_command)

func accepted_command(seat: int,command: Dictionary,action: Dictionary):
 observed.emit({"type":"command_accepted","seat":seat,"command":command.duplicate(true),"action":action.duplicate(true)})

func encode_command(seat: int,command: Dictionary) -> Dictionary:
 return Commands.encode(self,seat,command)

func submit(seat: int,command: Dictionary) -> String:
 if engine==null:return "教程对局尚未加载"
 if seat not in [0,1]:return "行动方必须为 0 或 1"
 var reason=Gateway.apply(engine,seat,command)
 poll()
 return reason

func reset_observation():
 last_revision=engine.revision;last_phase=engine.phase;last_priority=engine.priority

func poll():
 if engine==null or engine.revision==last_revision:return
 var phase_before=last_phase;var priority_before=last_priority;var revision_before=last_revision
 reset_observation()
 observed.emit({"type":"state_changed","before_revision":revision_before,"revision":last_revision})
 if phase_before!=last_phase:observed.emit({"type":"phase_changed","before":phase_before,"value":last_phase})
 if priority_before!=last_priority:observed.emit({"type":"priority_changed","before":priority_before,"value":last_priority})

func capture() -> Dictionary:
 return {"game":Codec.capture(engine) if engine!=null else {},"aliases":aliases.duplicate(true),"created_origin":created_origin,"components":components.duplicate(true),"scenario_id":scenario_id,"opponent":opponent_config.duplicate(true),"scene_type":scene_type,"scene_config":scene_config.duplicate(true),"ui_deck":ui_deck.duplicate(true),"last_ui_action":last_ui_action.duplicate(true)}

func restore(snapshot: Dictionary):
 scene_type=snapshot.get("scene_type","battlefield");scene_config=snapshot.get("scene_config",{}).duplicate(true)
 ui_deck=snapshot.get("ui_deck",{}).duplicate(true);last_ui_action=snapshot.get("last_ui_action",{}).duplicate(true)
 if not snapshot.game.is_empty():
  if engine==null:engine=Duel.new()
  Codec.restore(engine,snapshot.game)
 else:engine=null
 aliases=snapshot.aliases.duplicate(true);components=snapshot.components.duplicate(true)
 created_origin=int(snapshot.get("created_origin",engine.next_uid if engine!=null else 1))
 scenario_id=snapshot.scenario_id;opponent_config=snapshot.opponent.duplicate(true)
 if engine!=null:bind_commands();reset_observation()

func evaluate(c: Dictionary,completed: Array) -> bool:
 match c.type:
  "always":return true
  "all":return c.conditions.all(func(item):return evaluate(item,completed))
  "any":return c.conditions.any(func(item):return evaluate(item,completed))
  "not":return not evaluate(c.condition,completed)
  "steps_completed":return c.steps.all(func(id):return id in completed)
  "phase":return engine!=null and engine.phase==c.value
  "priority":return engine!=null and engine.priority==int(c.value)
  "pending":return engine!=null and engine.pending.get("kind","")==c.kind and engine.pending.get("owner",-1)==int(c.owner)
  "combat_attacker":
   var attacker=resolve_card(c)
   return engine!=null and not attacker.is_empty() and engine.combat.get("attacker",{})==engine.ref_target(attacker)
  "combat_step":return engine!=null and engine.combat.get("step","none")==c.value
  "entity_zone":return resolve_card(c).get("zone","")==c.zone
  "entity_state":
   var card=resolve_card(c)
   return not card.is_empty() and card.get(c.key,false)==c.value
  "entity_color_counter":return c.color in resolve_card(c).get("color_counters",[])
  "entity_count":
   var card=resolve_card(c)
   return not card.is_empty() and compare(int(card.get(c.key,0)),int(c.value),c.get("op","eq"))
  "zone_count":
   if engine==null:return false
   var cards=engine.players[int(c.player)].get(c.zone,[])
   if c.has("card_id"):cards=cards.filter(func(card):return card.card_id==c.card_id)
   if c.has("kind"):cards=cards.filter(func(card):return engine.cards[card.card_id].kind==c.kind)
   return compare(cards.size(),int(c.value),c.get("op","eq"))
  "player_count":
   if engine==null:return false
   var count=int(engine.players[int(c.player)].get(c.key,0))
   match c.get("op","eq"):
    "eq":return count==int(c.value)
    "le":return count<=int(c.value)
    "ge":return count>=int(c.value)
  "life":
   if engine==null:return false
   var life=engine.players[int(c.player)].life
   match c.get("op","eq"):
    "eq":return life==int(c.value)
    "le":return life<=int(c.value)
    "ge":return life>=int(c.value)
  "deck_count":
   var cards=[ui_deck.get("leader","")] if c.zone=="leader" else ui_deck.get(c.zone,[])
   var count=cards.count(c.card_id) if c.has("card_id") else cards.size()
   match c.get("op","eq"):
    "eq":return count==int(c.value)
    "le":return count<=int(c.value)
    "ge":return count>=int(c.value)
  "ui_action":
   if last_ui_action.get("id")!=c.action.id:return false
   for key in c.action.get("args",{}):
    if last_ui_action.get("args",{}).get(key)!=c.action.args[key]:return false
   return true
 return false

static func compare(actual: int,expected: int,op: String) -> bool:
 return actual==expected if op=="eq" else actual<=expected if op=="le" else actual>=expected
