extends SceneTree
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const Config=preload("res://scripts/tutorial/config.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Actions=preload("res://scripts/tutorial/opponent_actions.gd")
const Store=preload("res://scripts/deck_store.gd")
var checks=0
var failures=[]

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func fixture() -> Dictionary:
 var scene=Model.battle();scene.turn=6
 scene.players[0].hand=[{"card_id":"96","alias":"spell"},{"card_id":"96","alias":"second_spell"}]
 scene.players[0].palette=[{"card_id":"128"},{"card_id":"128"},{"card_id":"128"},{"card_id":"128"}]
 scene.players[0].field=[{"card_id":"53","alias":"attacker","state":{"entered":0,"entered_turns":0}}]
 scene.players[1].field=[{"card_id":"35","alias":"blocker","state":{"entered":0,"entered_turns":0}}]
 return {"schema_version":1,"id":"automatic_response","title":"自动响应任务","initial_scenario":"board","start_step":"task","completion":{"type":"always"},"scenarios":{"board":scene},"steps":{
  "task":{"type":"task","guide":{"text":"自由操作","popup":"hidden","next_button":"hidden"},"task":{"success":{"type":"life","player":1,"op":"le","value":0}},"next":"$complete"},
  "info":{"type":"info","guide":{"text":"暂停观察"},"next":"task"}}}

func start(data: Dictionary):
 var flow=Runtime.new();var reason=flow.start(data,Store.CARDS)
 expect(reason.is_empty(),"automatic-response scene starts: "+reason)
 if not reason.is_empty():flow.free();return null
 return flow

func ticks(flow,count: int=16):
 for i in range(count):flow.tick(0.1)

func cast(flow,alias: String,seat: int=0,target: Dictionary={"player":1}):
 var prepared=Actions.prepare(flow.adapter,{"type":"cast","card":{"alias":alias},"target":target},seat)
 expect(prepared.available and prepared.error.is_empty(),"real cast is available: "+alias)
 if prepared.available:expect(flow.adapter.submit(seat,prepared.command).is_empty(),"real cast accepted: "+alias)

func spell_and_gates():
 var flow=start(fixture())
 if flow==null:return
 var e=flow.adapter.engine;cast(flow,"spell")
 var snapshot=flow.capture();var before=e.revision
 flow.presentation_busy=func():return true
 ticks(flow);expect(e.revision==before and e.priority==1,"automatic response waits for presentation")
 flow.presentation_busy=Callable();flow.enter("info");ticks(flow)
 expect(e.revision==before and e.priority==1,"dialogue pauses automatic response")
 flow.next();ticks(flow)
 expect(e.priority==0 and e.stack.size()==1 and flow.opponent.counts.is_empty(),"unconfigured opponent passes the spell response without consuming a rule")
 expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"student resolves spell")
 expect(e.players[1].life==18 and flow.adapter.entity("spell").zone=="grave","automatic response preserves real spell damage")
 before=e.revision;ticks(flow)
 expect(e.revision==before and e.phase=="main","automatic response leaves student's idle main phase unchanged")
 expect(flow.restore(snapshot),"pending spell checkpoint restores")
 ticks(flow);expect(e.priority==0 and flow.opponent.config.auto_response,"checkpoint retains automatic response setting")
 flow.free()
 var data=fixture();data.scenarios.board.opponent.auto_response=false;flow=start(data)
 if flow!=null:
  cast(flow,"spell");before=flow.adapter.engine.revision;ticks(flow)
  expect(flow.adapter.engine.priority==1 and flow.adapter.engine.revision==before,"disabled automatic response preserves explicit waiting")
  flow.free()

func explicit_rules():
 var data=fixture();data.scenarios.board.opponent={"strategy":"rules","auto_response":true,"rules":[
  {"id":"reply","event":"state_changed","when":{"type":"priority","value":1},"action":{"type":"cast","card":{"alias":"reply_spell"},"target":{"player":0}},"max_times":1}]}
 data.scenarios.board.players[1].hand=[{"card_id":"96","alias":"reply_spell"}]
 data.scenarios.board.players[1].palette=[{"card_id":"128"},{"card_id":"128"}]
 var flow=start(data)
 if flow==null:return
 var e=flow.adapter.engine;cast(flow,"spell");ticks(flow)
 expect(e.stack.size()==2 and flow.opponent.counts.get("reply")==1 and flow.adapter.entity("reply_spell").zone=="stack","queued explicit cast takes precedence over automatic pass")
 expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"student passes explicit response")
 ticks(flow);expect(e.players[0].life==18 and e.stack.size()==1,"explicit response resolves through real rules")
 expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"student passes original spell")
 ticks(flow);expect(e.stack.is_empty() and e.players[1].life==18,"automatic response finishes original spell after custom response")
 cast(flow,"second_spell");ticks(flow)
 expect(e.priority==0 and flow.opponent.counts.get("reply")==1,"exhausted custom rule falls back without consuming additional uses")
 flow.free()

func combat_and_choices():
 for configured in [false,true]:
  var data=fixture()
  if configured:data.scenarios.board.opponent={"strategy":"rules","auto_response":true,"rules":[{"id":"block","event":"state_changed","when":{"type":"pending","kind":"block","owner":1},"action":{"type":"block","cards":[{"alias":"blocker"}]},"max_times":1}]}
  var flow=start(data)
  if flow==null:continue
  var e=flow.adapter.engine
  expect(flow.adapter.submit(0,{"name":"attack","args":[int(flow.adapter.entity("attacker").uid),{},[]]}).is_empty(),"student attacks")
  ticks(flow);expect(e.priority==0,"automatic response passes attack window")
  expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"student opens block choice")
  ticks(flow)
  expect(e.pending.is_empty() and e.combat.get("blocked",false)==configured,"explicit block overrides automatic decline" if configured else "unconfigured block choice automatically declines")
  for i in range(50):
   if e.combat.is_empty():break
   if e.pending.is_empty() and e.priority==0:flow.adapter.submit(0,{"name":"pass_priority","args":[]})
   flow.tick(0.1)
  expect(e.combat.is_empty() and flow.running,"automatic combat responses finish without stalling")
  flow.free()
 # A real player-owned entry choice must stay interactive; the same choice
 # owned by the opponent is completed before priority is handed back.
 for seat in [0,1]:
  var data=fixture();data.scenarios.board.priority=seat;data.scenarios.board.active=seat
  data.scenarios.board.players[seat].hand=[{"card_id":"character-fdn-068","alias":"lily"}]
  data.scenarios.board.players[seat].palette=[{"card_id":"128"}]
  var flow=start(data)
  if flow==null:continue
  var e=flow.adapter.engine;cast(flow,"lily",seat,{})
  if seat==0:
   ticks(flow);flow.adapter.submit(0,{"name":"pass_priority","args":[]})
  else:
   flow.adapter.submit(0,{"name":"pass_priority","args":[]});flow.tick()
  expect(e.pending.get("kind")=="effect_choice" and e.pending.get("owner")==seat,"Lily opens real color choice for seat "+str(seat))
  var before=e.revision;ticks(flow)
  if seat==0:
   expect(e.pending.get("owner")==0 and e.revision==before and flow.running,"automatic response leaves player's entry choice untouched")
  else:
   expect(e.pending.is_empty() and not e.stack.is_empty() and e.priority==0 and flow.running,"automatic response handles opponent's color choice and returns priority")
   flow.adapter.submit(0,{"name":"pass_priority","args":[]});ticks(flow)
   expect(not flow.adapter.entity("lily").get("color_counters",[]).is_empty(),"opponent's automatic color choice resolves")
  flow.free()

func validation():
 var data=fixture()
 expect(Config.new().validate(JSON.parse_string(JSON.stringify(data)),Store.CARDS).ok,"automatic response validates after save round trip")
 data.scenarios.board.opponent.auto_response="true"
 expect(not Config.new().validate(data,Store.CARDS).ok,"automatic response requires a boolean")

func mandatory_block():
 var data=fixture();data.scenarios.board.players[0].field=[{"card_id":"character-fdf-090","alias":"attacker","state":{"entered":0,"entered_turns":0}}]
 var flow=start(data)
 if flow==null:return
 var e=flow.adapter.engine
 expect(flow.adapter.submit(0,{"name":"attack","args":[int(flow.adapter.entity("attacker").uid),{},[]]}).is_empty(),"Reisen declares mandatory-block attack")
 ticks(flow);flow.adapter.submit(0,{"name":"pass_priority","args":[]});ticks(flow)
 expect(flow.running and e.pending.is_empty() and e.combat.get("blocked",false) and flow.adapter.entity("blocker").tapped,"automatic response obeys mandatory blocking instead of declining")
 flow.free()

func _initialize():
 validation();spell_and_gates();explicit_rules();combat_and_choices();mandatory_block()
 print("TUTORIAL AUTOMATIC RESPONSE: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
