extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Recorder=preload("res://scripts/tutorial/battle_recorder.gd")
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Sequence=preload("res://scripts/tutorial/sequence.gd")
const Config=preload("res://scripts/tutorial/config.gd")
var failures=[]
var checks=0

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func mono(color: String) -> String:
 for id in Store.CARDS:
  if Store.CARDS[id].get("colors",[])==[color] and not id.begins_with("roster_token"):return id
 return "53"

func scene() -> Dictionary:
 var s=Model.battle();s.players[0].field=[{"card_id":"53","alias":"a"}];s.players[1].field=[{"card_id":"53","alias":"b"}]
 for who in range(2):
  s.players[who].palette=[]
  for color in ["红","红","红","蓝","蓝","绿"]:s.players[who].palette.append({"card_id":mono(color)})
  s.players[who].deck_order=[]
  for i in range(8):s.players[who].deck_order.append({"card_id":"53"})
 return s

func record_combat():
 var r=Recorder.new();var input=scene();var untouched=input.duplicate(true)
 expect(r.configure(input,Store.CARDS).is_empty(),"recording configures real battle")
 expect(input==untouched,"opening recorder leaves source JSON untouched")
 expect(r.adapter.engine.debug_add("96",0,"hand").is_empty(),"native debug add is available before recording")
 expect(r.begin_record().is_empty(),"debug tableau becomes repeatable baseline")
 expect(r.scene.players[0].hand.size()==1 and r.scene.players[0].hand[0].has("alias"),"added hand card has persistent recording identity")
 var e=r.adapter.engine
 e.attack(1,int(r.adapter.entity("a").uid))
 expect(r.actions.is_empty(),"illegal moves are not recorded")
 e.attack(0,int(r.adapter.entity("a").uid))
 e.pass_priority(1);e.pass_priority(0)
 expect(e.pending.get("kind")=="block","recorded attack opens true block choice")
 e.block([int(r.adapter.entity("b").uid)])
 e.pass_priority(0);e.pass_priority(1);e.pass_priority(0);e.pass_priority(1)
 expect(r.actions.size()==8 and r.actions[0].card=={"alias":"a"} and r.actions[3].cards==[{"alias":"b"}],"both sides attack and block serialize as editable aliases")
 r.finish();expect(r.verify().is_empty(),"combat recording replays to identical rule state")
 expect(r.victory_candidates().any(func(item):return item.condition.get("type")=="entity_zone" and item.condition.get("alias")=="b"),"final board exposes individual victory predicates")
 expect(r.undo() and r.recording and r.actions.size()==7,"undo restores engine and action cursor")
 r.adapter.engine.pass_priority(r.adapter.engine.priority);r.finish()
 expect(r.verify().is_empty(),"recording after undo stays repeatable")
 return r

func course(r,interactive: bool=true) -> Dictionary:
 var data={"schema_version":1,"id":"recorded","title":"互动攻击阻挡","initial_scenario":"board","start_step":"task","completion":{"type":"always"},"scenarios":{"board":r.scene.duplicate(true)},"steps":{"task":{"type":"task","guide":{"text":"用 A 攻击，观察 B 阻挡。","next_button":"hidden"},"task":{"timing":"state_changed","success":{"type":"always"},"allow_turn_end":true},"next":"$complete"}}}
 if interactive:data.steps.task.task.sequence=r.sequence_config();data.steps.task.task.sequence.student=0
 return data

func practice(r):
 var data=course(r);expect(Config.new().validate(JSON.parse_string(JSON.stringify(data)),Store.CARDS).ok,"interactive sequence JSON validates")
 var flow=Runtime.new();expect(flow.start(data,Store.CARDS).is_empty(),"interactive runtime starts")
 var e=flow.adapter.engine;var revision=e.revision
 e.pass_priority(0)
 expect(e.revision==revision and flow.practice.index==0,"wrong student action is rejected before rule mutation")
 e.attack(0,int(flow.adapter.entity("a").uid))
 expect(flow.practice.index==1,"accepted native player attack advances one action")
 var checkpoint=flow.capture()
 for i in range(100):
  if not flow.running:break
  var config=flow.tutorial.steps.task.task.sequence
  if flow.practice.waiting_student(config):
   var prepared=Sequence.prepare(flow.adapter,config.actions[flow.practice.index],0)
   expect(prepared.available,"next student action is legal")
   flow.adapter.submit(0,prepared.command)
  flow.tick(0.25)
 expect(flow.finished and flow.adapter.entity("b").zone=="grave","opponent block plays automatically and task completes after all actions")
 expect(flow.restore(checkpoint) and flow.practice.index==1,"mid-practice restore resumes correct interactive cursor")
 expect(flow.reset_task() and flow.practice.index==0 and flow.adapter.entity("a").zone=="field","reset restores board, aliases, costs and task cursor")
 flow.free()

func response():
 var s=scene();s.players[0].hand=[{"card_id":"spell-fdf-003","alias":"light"}];s.players[1].hand=[{"card_id":"spell-fdn-069","alias":"flower"}]
 var r=Recorder.new();expect(r.configure(s,Store.CARDS).is_empty() and r.begin_record().is_empty(),"spell response recorder starts")
 var e=r.adapter.engine;var light=r.adapter.entity("light");var flower=r.adapter.entity("flower")
 expect(e.commit_cast(0,light.uid,{"none":true},e.payment(0,e.cast_cost(0,light,{"none":true})).plan).is_empty(),"author casts 逸脱者之光")
 expect(e.commit_cast(1,flower.uid,{"none":true},e.payment(1,e.cast_cost(1,flower,{"none":true})).plan).is_empty(),"author answers with 青花")
 e.pass_priority(0);e.pass_priority(1)
 var id=e.stack.filter(func(entry):return entry.get("card",{}).get("uid")==light.uid)[0].id
 e.choose_effect({"stack_id":id});r.finish()
 expect(r.actions.size()==5 and r.actions[4].target=={"stack":{"alias":"light"}},"resolution selection records stable stack source")
 expect(r.verify().is_empty(),"spell and stack target recording replays exactly")
 var rule=r.response_rule(0,1,1);expect(rule.on_action.card=={"card_id":"spell-fdf-003"},"AI trigger can match any same-name spell copy")
 var data=course(r,false);data.scenarios.board.opponent={"strategy":"rules","rules":[rule]};data.steps.task.task.success={"type":"life","player":1,"op":"le","value":0}
 expect(Config.new().validate(data,Store.CARDS).ok,"recorded response schema validates")
 var flow=Runtime.new();expect(flow.start(data,Store.CARDS).is_empty(),"recorded response runtime starts")
 var cast=Sequence.prepare(flow.adapter,r.actions[0],0);flow.adapter.submit(0,cast.command)
 for i in range(80):
  flow.tick(0.25)
  if flow.adapter.entity("flower").zone=="stack":break
 expect(flow.adapter.entity("flower").zone=="stack" and flow.opponent.counts.get(rule.id)==1,"real use of 逸脱者之光 triggers actual AI 青花 cast")
 flow.free()

func flexible_conditions(r):
 var data=course(r,false)
 data.steps.task.task.success={"type":"all","conditions":[{"type":"life","player":1,"op":"le","value":12},{"type":"zone_count","player":1,"zone":"field","kind":"单位","op":"le","value":1}]}
 var flow=Runtime.new();expect(flow.start(data,Store.CARDS).is_empty(),"generalized victory condition starts")
 var e=flow.adapter.engine;e.players[1].life=10;e.players[0].life=3;e.note("different successful tableau");flow.tick()
 expect(flow.finished,"threshold and zone count permit a different final board")
 flow.free()
 var validator=Config.new();validator.definitions=Store.CARDS
 validator.condition({"type":"entity_count","alias":"b","key":"damage","op":"ge","value":1},"condition",{})
 expect(validator.errors.is_empty(),"damage and counter predicates are editable")

func all_responses(r):
 var rules=r.response_rules()
 expect(rules.size()==4 and rules.any(func(rule):return rule.sequence.actions[0].type=="block"),"all enemy segments become phase-sensitive AI rules including block")
 var data=course(r,false);data.scenarios.board.opponent={"strategy":"rules","rules":rules}
 data.steps.task.task.success={"type":"life","player":1,"op":"le","value":0}
 var flow=Runtime.new();expect(flow.start(data,Store.CARDS).is_empty(),"multi-response free battle starts")
 var cursor=[0];var accepted=[]
 flow.adapter.observed.connect(func(event):
  if event.type=="command_accepted":
   accepted.append(event.action)
   if cursor[0]<r.actions.size() and preload("res://scripts/tutorial/battle_commands.gd").matches(flow.adapter,r.actions[cursor[0]],event.action):cursor[0]+=1)
 for i in range(600):
  if cursor[0]>=r.actions.size():break
  var action=r.actions[cursor[0]]
  if action.get("player")==0:
   var prepared=Sequence.prepare(flow.adapter,action,0)
   if prepared.available:flow.adapter.submit(0,prepared.command)
  flow.tick(0.25)
 expect(flow.running and cursor[0]==r.actions.size() and accepted.size()==r.actions.size(),"free battle AI reproduces every enemy response at its correct recorded trigger")
 expect(flow.adapter.entity("b").zone=="grave","recorded AI blocks with B and resolves real combat")
 flow.free()

func random_recording():
 var s=scene();s.players[0].field=[{"card_id":"character-lof-001","alias":"die","state":{"courage":2,"leader_counters":1}}]
 var r=Recorder.new();expect(r.configure(s,Store.CARDS).is_empty() and r.begin_record().is_empty(),"random ability recorder starts")
 var move={"type":"ability","player":0,"source":{"alias":"die"},"key":"courage_die","target":{"alias":"b"}}
 var prepared=Sequence.prepare(r.adapter,move,0);expect(prepared.available,"random ability uses real legal targets and payment")
 if not prepared.available:return
 expect(r.adapter.submit(0,prepared.command).is_empty(),"random ability commits")
 expect(r.random_results.size()==1 and r.random_results[0].type=="d6","real die result is recorded")
 r.adapter.engine.pass_priority(1);r.adapter.engine.pass_priority(0);r.finish()
 expect(r.verify().is_empty(),"random replay preserves result and natural RNG progression")
 expect(r.undo() and r.undo() and r.undo() and r.random_results.is_empty(),"undoing random action restores results and RNG origin")
 prepared=Sequence.prepare(r.adapter,move,0);r.adapter.submit(0,prepared.command)
 r.adapter.engine.pass_priority(1);r.adapter.engine.pass_priority(0);r.finish()
 expect(r.verify().is_empty(),"rerecording randomness after undo remains deterministic")
 r.reset_setup()
 expect(not r.recording and r.actions.is_empty() and r.random_results.is_empty(),"returning to setup clears the isolated action timeline")
 expect(r.adapter.engine.debug_add("96",0,"hand").is_empty() and r.begin_record().is_empty(),"setup can add cards and start a fresh recording without losing its tableau")

func failure_during_practice(r):
 var data=course(r)
 data.steps.task.task.failure={"type":"entity_state","alias":"a","key":"attacked","value":true}
 data.steps.task.failure="task";data.steps.task.restore_on_failure=true
 var flow=Runtime.new();expect(flow.start(data,Store.CARDS).is_empty(),"interactive failure condition starts")
 var notices=[];flow.task_failed.connect(func(detail):notices.append(detail))
 flow.adapter.engine.attack(0,int(flow.adapter.entity("a").uid));flow.tick()
 expect(notices.size()==1 and flow.practice.index==0 and not flow.adapter.entity("a").attacked,"failure predicate is evaluated while recorded practice is still running")
 flow.free()

func setup_hand_deletion():
 var input=Model.battle();input.players[0].hand=[{"card_id":"53","alias":"remove"},{"card_id":"53","alias":"keep"}]
 input.players[1].hand=[{"card_id":"96","alias":"enemy"}]
 var before=input.duplicate(true);var r=Recorder.new();r.configure(input,Store.CARDS)
 var e=r.adapter.engine;var uid=int(r.adapter.entity("remove").uid);var keep=int(r.adapter.entity("keep").uid)
 expect(not r.remove_setup_hand_card(int(r.adapter.entity("student_leader").uid)),"setup deletion only accepts hand cards")
 expect(r.remove_setup_hand_card(uid),"setup deletes the selected hand instance")
 expect(e.players[0].hand.size()==1 and e.players[0].hand[0].uid==keep and r.adapter.entity("remove").is_empty(),"same-name copy and its alias survive deleting a different copy")
 expect(r.remove_setup_hand_card(int(r.adapter.entity("enemy").uid)) and e.players[1].hand.is_empty(),"setup can delete the other side's hand card")
 expect(input==before and r.actions.is_empty() and r.points.is_empty(),"setup deletion leaves source course and recorded timeline untouched")
 expect(e.players[0].grave.is_empty() and e.players[0].exile.is_empty() and e.triggers.is_empty() and e.presentation_events.is_empty(),"direct deletion produces no discard effects or zone moves")
 expect(r.begin_record().is_empty() and r.scene.players[0].hand.size()==1 and r.scene.players[1].hand.is_empty(),"deleted cards are absent from the captured recording baseline")
 expect(not r.remove_setup_hand_card(int(r.adapter.entity("keep").uid)),"hand deletion is disabled during recording")
 e=r.adapter.engine;e.pass_priority(0);r.finish()
 expect(r.verify().is_empty(),"recording from the edited hand replays exactly")
 expect(r.seek(0) and not r.remove_setup_hand_card(int(r.adapter.entity("keep").uid)),"browsing the first recorded boundary cannot edit setup")
 r.reset_setup()
 expect(r.remove_setup_hand_card(int(r.adapter.entity("keep").uid)),"explicit reset enables setup deletion again")

func setup_card_editing():
 var input=Model.battle()
 for who in range(2):
  for zone in Config.ZONES:
   input.players[who]["deck_order" if zone=="deck" else zone]=[{"card_id":"53","alias":zone+str(who),"state":{"tapped":true,"plus_counters":2,"color_counters":["蓝"]}}]
 var before=input.duplicate(true);var r=Recorder.new()
 expect(r.configure(input,Store.CARDS).is_empty(),"all-zone setup loads")
 var e=r.adapter.engine
 for who in range(2):
  expect(r.set_setup_life(who,11+who),"setup changes either player's initial life")
  for zone in Config.ZONES:
   var original=r.adapter.entity(zone+str(who));var uid=int(original.uid)
   var copy_uid=r.copy_setup_card(uid);var copy=e.find_card(copy_uid)
   expect(copy_uid>0 and copy_uid!=uid and copy.zone==zone and copy.owner==who,"copy stays in the same side and zone: "+zone+str(who))
   expect(copy.tapped and copy.plus_counters==2 and copy.color_counters==["蓝"],"copy retains configured state: "+zone+str(who))
   copy.color_counters.append("红")
   expect(original.color_counters==["蓝"],"copy's counters are independent: "+zone+str(who))
   expect(r.remove_setup_card(uid) and e.players[who][zone].size()==1 and e.players[who][zone][0].uid==copy_uid,"delete targets only the selected instance: "+zone+str(who))
  var leader=e.players[who].leader
  expect(not r.remove_setup_card(int(leader.uid)),"deck leader cannot be deleted")
  var leader_copy=r.copy_setup_card(int(leader.uid))
  expect(e.find_card(leader_copy).zone=="leader" and e.leaders(who).size()==2,"C copies a leader within its leader zone")
 expect(not r.set_setup_life(0,0) and not r.set_setup_life(2,10),"initial life rejects invalid values and sides")
 expect(input==before and r.points.is_empty() and r.actions.is_empty() and e.triggers.is_empty() and e.presentation_events.is_empty(),"setup edits produce no gameplay effects, recording actions or source writes")
 var leader_uid=int(e.players[0].leader.uid)
 for zone in Config.ZONES+["leader"]:
  expect(e.debug_move(leader_uid,zone).is_empty() and not r.remove_setup_card(leader_uid),"deck leader remains protected after moving to "+zone)
 expect(r.begin_record().is_empty(),"all-zone edits become a validated recording baseline")
 e=r.adapter.engine
 expect(e.players[0].life==11 and e.players[1].life==12 and e.leaders(0).size()==2 and e.leaders(1).size()==2,"life and leader-zone copies survive reconstruction")
 for who in range(2):
  for zone in Config.ZONES:expect(e.players[who][zone].size()==1 and e.players[who][zone][0].color_counters==["蓝","红"],"zone copies round-trip independently: "+zone+str(who))
 expect(r.copy_setup_card(int(e.players[0].hand[0].uid))==0 and not r.remove_setup_card(int(e.players[0].hand[0].uid)) and not r.set_setup_life(0,5),"all setup edits stop when recording begins")
 var secondary=Model.battle();secondary.players[0].leader.card_id="new-eto-001"
 var extra=Recorder.new();expect(extra.configure(secondary,Store.CARDS).is_empty(),"automatic extra leader setup loads")
 expect(extra.remove_setup_card(int(extra.adapter.engine.players[0].extra_leaders[0].uid)) and extra.begin_record().is_empty() and extra.adapter.engine.leaders(0).size()==1,"deleting an extra leader is saved without regenerating it")

func setup_unit_readiness():
 var input=scene();input.turn=6
 input.players[0].state={"turns":4};input.players[1].state={"turns":2}
 input.players[0].field.append({"card_id":"53","alias":"same_name"})
 input.players[0].hand=[{"card_id":"53","alias":"hand"}]
 input.players[0].palette.append({"card_id":"53","alias":"palette"})
 input.players[0].leader_on_field=true
 var before=input.duplicate(true);var r=Recorder.new()
 expect(r.configure(input,Store.CARDS).is_empty(),"individual unit setup loads")
 var e=r.adapter.engine;var a=r.adapter.entity("a");var b=r.adapter.entity("b")
 expect(e.can_attack(0,int(a.uid)),"a ready unit can attack before setup toggle")
 expect(r.toggle_setup_unit_ready(int(a.uid)) and e.summoning_sick(a) and not e.can_attack(0,int(a.uid)),"P closes the chosen unit's entry-age action gate")
 expect(not e.summoning_sick(r.adapter.entity("same_name")) and not e.summoning_sick(b),"same-name copies and the other player retain their readiness")
 expect(r.toggle_setup_unit_ready(int(a.uid)) and not e.summoning_sick(a) and e.can_attack(0,int(a.uid)),"P opens the action gate on the next press")
 expect(r.toggle_setup_unit_ready(int(a.uid)) and r.toggle_setup_unit_ready(int(b.uid)) and e.summoning_sick(a) and e.summoning_sick(b),"both sides use their own turn counts")
 var leader=r.adapter.entity("student_leader")
 expect(r.toggle_setup_unit_ready(int(leader.uid)) and e.summoning_sick(leader),"a leader on the battlefield also has individual readiness")
 for alias in ["hand","palette","enemy_leader"]:
  expect(not r.toggle_setup_unit_ready(int(r.adapter.entity(alias).uid)),"P ignores units outside the battlefield: "+alias)
 expect(not r.toggle_setup_unit_ready(-1),"P ignores a missing instance")
 var copy_uid=r.copy_setup_card(int(a.uid));var copy=e.find_card(copy_uid)
 expect(e.summoning_sick(copy),"copy inherits the chosen unit's closed action gate")
 expect(r.toggle_setup_unit_ready(copy_uid) and not e.summoning_sick(copy) and e.summoning_sick(a),"copy readiness can be changed independently")
 var haste_cards=Store.CARDS.duplicate(true);haste_cards["53"].keywords.append("疾行")
 var haste=Recorder.new();expect(haste.configure(input,haste_cards).is_empty(),"haste unit setup loads")
 var h=haste.adapter.entity("a");var he=haste.adapter.engine
 expect(he.has_haste(h) and haste.toggle_setup_unit_ready(int(h.uid)) and not he.summoning_sick(h),"P retains the normal haste exception")
 expect(haste.toggle_setup_unit_ready(int(h.uid)) and h.entered_turns<he.players[0].turns,"P can reopen entry age even when haste bypasses summoning sickness")
 expect(input==before and r.actions.is_empty() and r.points.is_empty() and e.triggers.is_empty() and e.presentation_events.is_empty(),"readiness setup leaves the source and gameplay timeline untouched")
 var board=r.tableau();var reopened=Recorder.new()
 expect(reopened.configure(JSON.parse_string(JSON.stringify(board)),Store.CARDS).is_empty(),"individual states round-trip through course JSON")
 var restored=reopened.adapter.engine
 expect(restored.summoning_sick(reopened.adapter.entity("a")) and restored.summoning_sick(reopened.adapter.entity("b")) and restored.summoning_sick(reopened.adapter.entity("student_leader")),"saved and reopened units keep their individually closed gates")
 expect(JSON.parse_string(JSON.stringify(reopened.tableau()))==JSON.parse_string(JSON.stringify(board)),"reopening preserves the scene despite the default ready-units option")
 expect(r.begin_record().is_empty(),"mixed unit readiness becomes the recording baseline")
 e=r.adapter.engine
 expect(e.summoning_sick(r.adapter.entity("a")) and e.summoning_sick(r.adapter.entity("b")) and not e.summoning_sick(r.adapter.entity("same_name")),"recording retains individual settings over the global default")
 expect(not r.toggle_setup_unit_ready(int(r.adapter.entity("a").uid)),"P cannot edit readiness during recording")
 e.pass_priority(0);r.finish()
 expect(r.verify().is_empty(),"mixed-readiness recording replays through the real engine")
 expect(r.seek(0) and not r.toggle_setup_unit_ready(int(r.adapter.entity("a").uid)),"P cannot edit a recorded checkpoint")
 r.reset_setup()
 expect(r.toggle_setup_unit_ready(int(r.adapter.entity("a").uid)),"resetting to setup enables P again")

func _initialize():
 var r=record_combat();practice(r);response();flexible_conditions(r);all_responses(r);random_recording();failure_during_practice(r);setup_hand_deletion();setup_card_editing();setup_unit_readiness()
 print("TUTORIAL RECORDING: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
