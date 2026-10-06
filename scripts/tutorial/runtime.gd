extends Node
## Progress belongs to this node, independently of the guide's visibility.
const Adapter=preload("res://scripts/tutorial/game_adapter.gd")
const Opponent=preload("res://scripts/tutorial/opponent.gd")
const Sequence=preload("res://scripts/tutorial/sequence.gd")
const Practice=preload("res://scripts/tutorial/interactive_sequence.gd")
signal step_changed(id: String,step: Dictionary)
signal checkpoint_ready(id: String,snapshot: Dictionary)
signal scenario_changed
signal completed(id: String)
signal failed(reason: String)
signal task_failed(reason: String)
signal sequence_changed(playing: bool)
var action_failures: Array=[]
var adapter=Adapter.new()
var opponent=Opponent.new()
var sequence=Sequence.new()
var practice=Practice.new()
var presentation_busy: Callable
var tutorial: Dictionary={}
var course_path=""
var definitions: Dictionary={}
var current_step=""
var completed_steps: Array=[]
var running=false
var finished=false
var events: Array=[]
var epoch=0
var checkpoint: Dictionary={}
var last_error=""
var scenario_states: Dictionary={}
var history: Array=[]
var previous_checkpoint: Callable
var presentation: Dictionary={"camera_view":"","open_zone":{}}

func _init():
 adapter.observed.connect(observe)

func start(data: Dictionary,cards: Dictionary) -> String:
 # Callers provide Config's validated copy; still validate at this public entry.
 var checked=preload("res://scripts/tutorial/config.gd").new().validate(data,cards)
 if not checked.ok:return stop("\n".join(checked.errors))
 tutorial=checked.data;definitions=cards
 completed_steps=[];events=[];action_failures=[];scenario_states={};history=[];finished=false;running=true;last_error=""
 adapter.scenario_id=""
 var reason=load_scenario(tutorial.initial_scenario)
 if not reason.is_empty():return reason
 enter(tutorial.start_step)
 return last_error

func load_scenario(id: String,mode: String="reset") -> String:
 if not adapter.scenario_id.is_empty():
  scenario_states[adapter.scenario_id]={"adapter":adapter.capture(),"opponent":opponent.capture(),"presentation":presentation.duplicate(true)}
 if mode=="resume" and scenario_states.has(id):
  var state=scenario_states[id]
  adapter.restore(state.adapter);opponent.restore(state.opponent)
  presentation=state.get("presentation",{"camera_view":"","open_zone":{}}).duplicate(true)
  # Responses queued for the previous step cannot run in a different scene.
  opponent.events.clear()
  if adapter.engine!=null:adapter.engine.presentation_events.clear()
 else:
  var reason=adapter.load_scenario(id,tutorial.scenarios[id],definitions)
  if not reason.is_empty():return stop(reason)
  opponent.configure(adapter.opponent_config)
  presentation={"camera_view":"","open_zone":{}}
 events.clear()
 bind_practice()
 scenario_changed.emit()
 return ""

func observe(event: Dictionary):
 # Stamp events so one accepted move cannot solve multiple successive steps.
 events.append({"epoch":epoch,"event":event.duplicate(true)})
 if event.type=="command_accepted" and running and practice.playing:
  practice.accepted(tutorial.steps[current_step].task.sequence,int(event.seat))
 if not playing_sequence() and not practice.playing:opponent.observe(event)

func bind_practice():
 if adapter.engine!=null:adapter.engine.command_filter=authorize_battle_command

func authorize_battle_command(seat: int,command: Dictionary) -> bool:
 if not running or not practice.playing:return true
 var config=tutorial.steps[current_step].task.sequence
 if practice.permits(adapter,config,seat,command):return true
 var expected=config.actions[practice.index] if practice.index<config.actions.size() else {}
 task_failed.emit("请按动作顺序完成任务："+preload("res://scripts/tutorial/battle_commands.gd").caption(adapter,expected))
 return false

func enter(id: String):
 if not running:return
 if id=="$complete":
  if not adapter.evaluate(tutorial.completion,completed_steps):stop("completion：到达终点但课程完成条件不成立");return
  if adapter.engine!=null:adapter.engine.tutorial_turn_end_blocked=false
  running=false;finished=true;events.clear();opponent.events.clear();completed.emit(tutorial.id);return
 current_step=id;epoch+=1
 adapter.last_ui_action={}
 var s=tutorial.steps[id]
 if s.has("scenario") and not load_scenario(s.scenario,s.get("scenario_mode","reset")).is_empty():return
 var reason=missing_alias(s)
 if not reason.is_empty():stop("steps.%s.%s" % [id,reason]);return
 sequence.start(adapter,s.get("sequence",{}))
 if s.get("task",{}).has("sequence"):practice.start(adapter,s.task.sequence)
 else:practice.playing=false;practice.index=0
 sync_turn_end_permission()
 if s.has("camera_view"):presentation.camera_view=s.camera_view
 presentation.open_zone=s.get("open_zone",{}).duplicate(true)
 step_changed.emit(id,s)
 observe({"type":"step_entered","step_id":id})
 checkpoint={}
 checkpoint=capture()
 checkpoint_ready.emit(id,checkpoint)
 sequence_changed.emit(playing_sequence())
 schedule_entry(s)

func schedule_entry(s: Dictionary):
 if playing_sequence():return
 if s.type=="info" and s.guide.get("next_button","manual")=="auto":call_deferred("auto_advance",epoch)
 elif s.type=="task" and s.task.get("timing","state_changed")=="enter":call_deferred("evaluate_enter",epoch)

func missing_alias(value: Variant,path: String="") -> String:
 if value is Dictionary:
  for key in value:
   if key=="alias" and adapter.entity(value[key]).is_empty():return path+".alias：当前场景没有实体别名 "+str(value[key])
   var reason=missing_alias(value[key],path+"."+str(key))
   if not reason.is_empty():return reason
 elif value is Array:
  for i in range(value.size()):
   var reason=missing_alias(value[i],path+"."+str(i))
   if not reason.is_empty():return reason
 return ""

func auto_advance(expected_epoch: int):
 if running and epoch==expected_epoch:advance()

func evaluate_enter(expected_epoch: int):
 if not running or epoch!=expected_epoch:return
 evaluate_task()
 if running and epoch==expected_epoch:stop("steps.%s.task.timing：enter 判定未匹配成功或失败条件，无法继续" % current_step)

func next() -> bool:
 if not running or playing_sequence():return false
 var s=tutorial.steps[current_step]
 if s.type!="info" or s.guide.get("next_button","manual")!="manual":return false
 advance();return true

func advance():
 # Checkpoints are immutable once captured. Copy only the outer dictionary;
 # duplicating every earlier game snapshot here grows with the whole lesson.
 var previous=checkpoint.duplicate();previous.erase("history");history.append(previous)
 if current_step not in completed_steps:completed_steps.append(current_step)
 enter(tutorial.steps[current_step].next)

func can_previous() -> bool:
 return (running or finished) and not playing_sequence() and (not history.is_empty() or previous_checkpoint.is_valid() and not completed_steps.is_empty() and completed_steps.back()!=current_step)

func previous() -> bool:
 if not can_previous():return false
 if history.is_empty():
  var saved=previous_checkpoint.call()
  return not saved.is_empty() and restore(saved)
 var snapshot=history.pop_back().duplicate()
 snapshot.history=history.duplicate()
 return restore(snapshot)

func can_reset_task() -> bool:
 return running and tutorial.steps[current_step].type in ["task","wait"] and not answering() and checkpoint.get("step")==current_step

func reset_task() -> bool:
 if not can_reset_task():return false
 return restore(checkpoint)

func playing_sequence() -> bool:
 return running and sequence.playing

func can_replay_sequence() -> bool:
 return running and not playing_sequence() and tutorial.steps[current_step].has("sequence") and checkpoint.get("step")==current_step

func replay_sequence() -> bool:
 if not can_replay_sequence():return false
 return restore(checkpoint)

func answering() -> bool:
 return running and tutorial.steps[current_step].type=="task" and tutorial.steps[current_step].task.get("timing")=="answer"

func allows_turn_end() -> bool:
 if not running or current_step.is_empty():return true
 var s=tutorial.steps[current_step]
 return s.type not in ["task","wait"] or s.task.get("allow_turn_end",false)

func sync_turn_end_permission():
 if adapter.engine!=null:adapter.engine.tutorial_turn_end_blocked=not allows_turn_end()

func permits_match_actions() -> bool:
 if not running:return false
 var s=tutorial.steps[current_step]
 return s.type=="task" and s.task.get("timing","state_changed") not in ["answer","enter"]

func submit_answer(id: String,expected_epoch: int) -> bool:
 if not answering() or expected_epoch!=epoch:return false
 var quiz=tutorial.steps[current_step].task.quiz
 if not quiz.answers.any(func(answer):return answer.id==id):return false
 if id!=quiz.correct_answer:
  task_failed.emit("答案不正确，请重新选择。")
  return false
 advance();return true

func submit_mulligan_selection(uids: Array) -> bool:
 if not running or tutorial.steps[current_step].type!="task":return false
 var task=tutorial.steps[current_step].task
 if task.has("sequence") and adapter.engine!=null:
  var before=adapter.engine.revision
  adapter.engine.mulligan(int(task.sequence.get("student",0)),uids)
  return adapter.engine.revision!=before
 if task.get("timing")!="mulligan_selection" or adapter.engine==null or adapter.engine.phase!="mulligan":return false
 var required: Array=[]
 for alias in task.required_aliases:required.append(int(adapter.entity(alias).get("uid",-1)))
 if uids.size()!=required.size() or uids.duplicate().filter(func(uid):return uid in required).size()!=required.size() or uids[0]==uids[1]:
  task_failed.emit("请选择指引中的两张手牌，再确认调度。")
  return false
 var reason=adapter.submit(0,{"name":"mulligan","args":[uids]})
 if not reason.is_empty():
  task_failed.emit("调度未完成："+reason)
  return false
 advance()
 return true

func submit_effect_choice(target: Dictionary) -> bool:
 if not permits_match_actions() or adapter.engine==null:return false
 var s=tutorial.steps[current_step]
 if s.type=="task" and s.task.has("required_choice"):
  var required=s.task.required_choice
  var pending=adapter.engine.pending
  if pending.get("kind","")=="effect_choice" and pending.get("owner",-1)==0 and pending.get("trigger",{}).get("effect","")==required.effect and target.get("color","")!=required.color:
   task_failed.emit("这一步请选择%s色。" % required.color)
   return false
 var reason=adapter.submit(0,{"name":"choose_effect","args":[target]})
 if not reason.is_empty():
  task_failed.emit("选择未完成："+reason)
  return false
 return true

func evaluate_task(allow_success: bool=true):
 var s=tutorial.steps[current_step];var task=s.task
 # Failure wins when both predicates match. Roll back only when declared.
 if task.has("failure") and adapter.evaluate(task.failure,completed_steps):
  if s.get("restore_on_failure",false):restore(checkpoint)
  enter(s.failure)
  task_failed.emit("任务未完成，请按提示重试。"+("已恢复到任务开始时的局面。" if s.get("restore_on_failure",false) else ""))
 elif allow_success and not practice.playing and adapter.evaluate(task.success,completed_steps):advance()

func _process(delta):
 tick(delta)

func tick(delta: float=1.0/60.0):
 if not running:return
 adapter.poll()
 var batch=events;events=[]
 if playing_sequence():
  var busy=presentation_busy.is_valid() and presentation_busy.call()
  var reason=sequence.tick(adapter,tutorial.steps[current_step].sequence,delta,busy)
  if not reason.is_empty():stop("steps.%s.sequence.%s" % [current_step,reason]);return
  if not sequence.playing:
   sequence_changed.emit(false)
  return
 # Answer dialogs hold the scene and opponent until the correct selection.
 if answering():return
 if tutorial.steps[current_step].get("task",{}).has("sequence") and practice.playing:
  if batch.any(func(item):return item.epoch==epoch and item.event.type=="state_changed"):
   var original_epoch=epoch
   evaluate_task(false)
   if not running or epoch!=original_epoch:return
  var was_waiting=practice.waiting_student(tutorial.steps[current_step].task.sequence)
  var reason=practice.tick_interactive(adapter,tutorial.steps[current_step].task.sequence,delta,presentation_busy.is_valid() and presentation_busy.call())
  if not reason.is_empty():stop("steps.%s.task.sequence.%s" % [current_step,reason]);return
  if was_waiting!=practice.waiting_student(tutorial.steps[current_step].task.sequence):sequence_changed.emit(false)
  if not practice.playing:evaluate_task()
  return
 for item in batch:
  if not running or item.epoch!=epoch:continue
  var s=tutorial.steps[current_step];var event=item.event
  if s.type=="task" and s.task.get("timing","state_changed")=="state_changed" and event.type=="state_changed":evaluate_task()
  elif s.type=="task" and s.task.get("timing")=="action" and event.type=="ui_action_accepted":
   adapter.last_ui_action={"id":event.action,"args":event.args.duplicate(true)}
   evaluate_task(action_matches(s.task.action,event.action,event.args))
  elif s.type=="wait" and event.type==s.wait_event:
   evaluate_task()
   if running and item.epoch==epoch and event.type=="step_entered":stop("steps.%s.task：进入步骤时未匹配条件，无法继续" % current_step)
 # A dialogue is a stable view of the board. Queued opponent responses resume
 # only after the next task begins.
 if running and tutorial.steps[current_step].type!="info":
  var reason=opponent.tick(adapter,completed_steps,delta,presentation_busy.is_valid() and presentation_busy.call())
  if not reason.is_empty():stop(reason)

func capture() -> Dictionary:
 var state={"course_id":tutorial.id,"step":current_step,"completed_steps":completed_steps.duplicate(),"adapter":adapter.capture(),"opponent":opponent.capture(),"sequence":sequence.capture(),"practice":practice.capture(),"events":events.duplicate(true),"epoch":epoch,"scenario_states":scenario_states.duplicate(),"history":history.duplicate(),"presentation":presentation.duplicate(true)}
 if (tutorial.steps.get(current_step,{}).has("sequence") or tutorial.steps.get(current_step,{}).get("task",{}).has("sequence")) and checkpoint.get("step")==current_step:
  var origin=checkpoint.duplicate();origin.erase("sequence_origin")
  state.sequence_origin=origin
 return state

func restore(snapshot: Dictionary) -> bool:
 if snapshot.get("course_id")!=tutorial.get("id"):stop("checkpoint：检查点不属于本课程");return false
 adapter.restore(snapshot.adapter);opponent.restore(snapshot.opponent)
 sequence.restore(snapshot.get("sequence",{}))
 practice.restore(snapshot.get("practice",{}));bind_practice()
 scenario_states=snapshot.get("scenario_states",{}).duplicate()
 current_step=snapshot.step;completed_steps=snapshot.completed_steps.duplicate()
 history=snapshot.get("history",[]).duplicate()
 presentation=snapshot.get("presentation",{"camera_view":"","open_zone":{}}).duplicate(true)
 # Invalidate deferred transitions from the previous timeline.
 epoch+=1;events=[];running=true;finished=false;last_error=""
 for item in snapshot.events:
  if item.epoch==snapshot.epoch:events.append({"epoch":epoch,"event":item.event.duplicate(true)})
 sync_turn_end_permission()
 scenario_changed.emit();step_changed.emit(current_step,tutorial.steps[current_step])
 # Mid-demonstration restores resume their cursor, but replay always starts
 # from the original entrance, including costs, random results and RNG state.
 checkpoint=snapshot.get("sequence_origin",{})
 if checkpoint.is_empty():checkpoint=snapshot
 sequence_changed.emit(playing_sequence())
 schedule_entry(tutorial.steps[current_step])
 return true

func action_matches(expected: Dictionary,id: String,args: Dictionary) -> bool:
 if expected.id!=id:return false
 for key in expected.get("args",{}):
  if not args.has(key) or args[key]!=expected.args[key]:return false
 return true

func authorize_ui_action(id: String,args: Dictionary) -> bool:
 var actions=preload("res://scripts/tutorial/ui_actions.gd")
 if not running:return false
 if answering() or playing_sequence():return false
 # Card inspection is the one background action available during dialogue.
 if id=="editor.inspect":return true
 if adapter.scene_type=="deck":return false
 var s=tutorial.steps[current_step]
 if s.type=="info":return false
 if not adapter.components.get("interaction",{}).get("enabled",true):reject_ui_action(id,args);return false
 if id in actions.ALLOWED and s.type=="task" and s.task.get("timing")=="action":
  if action_matches(s.task.action,id,args) or id in s.task.get("allowed_actions",[]):return true
 reject_ui_action(id,args)
 return false

func ui_action_applied(id: String,args: Dictionary):
 adapter.last_ui_action={"id":id,"args":args.duplicate(true)}
 observe({"type":"ui_action_accepted","action":id,"args":args.duplicate(true)})

func reject_ui_action(id: String,args: Dictionary,detail: String=""):
 var s=tutorial.steps[current_step]
 # Ordinary dialogue has no required operation and cannot fail a task.
 if s.type=="info":return
 action_failures.append({"step":current_step,"action":id,"args":args.duplicate(true)})
 var reason="操作不符合当前任务，请按提示重试。错误指令未执行。" if detail.is_empty() else detail
 if s.type=="task" and s.has("failure"):
  if s.get("restore_on_failure",false):restore(checkpoint)
  enter(s.failure)
 task_failed.emit(reason)

func stop(reason: String) -> String:
 sequence.playing=false
 practice.playing=false
 if adapter.engine!=null:
  adapter.engine.tutorial_turn_end_blocked=false
  adapter.engine.scripted_random=false
 running=false;last_error=reason if reason.begins_with("课程 ") else "课程 %s · %s" % [tutorial.get("id","?"),reason]
 failed.emit(last_error)
 return last_error
