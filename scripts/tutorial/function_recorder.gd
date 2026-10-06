extends RefCounted
## Accepted native UI operations become individually editable task nodes.
const Adapter=preload("res://scripts/tutorial/game_adapter.gd")
const Config=preload("res://scripts/tutorial/config.gd")
const Actions=preload("res://scripts/tutorial/ui_actions.gd")
signal changed
var adapter=Adapter.new()
var scene: Dictionary={}
var definitions: Dictionary={}
var actions: Array=[]
var points: Array=[]
var nodes: Array=[]
var recording=false
var replaying=false
var cursor=0
var replay_delay=0.0
var capture_ui: Callable
var restore_ui: Callable
var validation_steps: Dictionary={}
var validation_scenarios: Dictionary={}

func configure(value: Dictionary,cards: Dictionary) -> String:
 definitions=cards;scene=value.duplicate(true)
 var check=Config.new();check.definitions=cards;check.scenario(scene,"recording",{})
 if not check.errors.is_empty():return "\n".join(check.errors)
 return adapter.load_scenario("recording",scene,cards)

func begin_record() -> String:
 scene.deck=clean_deck(adapter.ui_deck)
 actions=[];nodes=[];cursor=0;points=[capture_point()];recording=true;changed.emit();return ""

func capture_point() -> Dictionary:
 var point=adapter.capture()
 if capture_ui.is_valid():point.recording_ui=capture_ui.call()
 return point

static func clean_deck(deck: Dictionary) -> Dictionary:
 return {"name":deck.name,"leader":deck.leader,"main":deck.main.duplicate(),"side":deck.side.duplicate(),"rule_set":deck.get("rule_set","official")}

func accepted(id: String,args: Dictionary):
 if not recording:return
 var action={"id":id,"args":args.duplicate(true)}
 # Copy indices are presentation details. Match the card and intended zone.
 for key in ["source_index","target_index"]:action.args.erase(key)
 if id=="editor.remove" and not action.args.has("zone") and action.args.has("source_zone"):action.args.zone=action.args.source_zone
 if id in ["editor.add","editor.remove","editor.inspect"]:action.args.erase("source_zone")
 if id=="editor.inspect":action.args.erase("zone")
 # Typing a search is one instruction, rather than a node for every letter.
 if id=="editor.search" and not actions.is_empty() and actions.back().id==id:
  actions.pop_back();nodes.pop_back();points.pop_back()
 actions.append(action)
 var success={"type":"ui_action","action":action.duplicate(true)}
 if id in ["editor.add","editor.remove","editor.move"] and args.has("card_id"):
  var zone=args.get("zone",args.get("source_zone","main"))
  if zone in ["main","side","leader"]:
   var ids=[adapter.ui_deck.leader] if zone=="leader" else adapter.ui_deck[zone]
   success={"type":"deck_count","zone":zone,"card_id":args.card_id,"op":"eq","value":ids.count(args.card_id)}
 var guide={"text":Actions.caption(action,definitions),"next_button":"hidden"}
 if adapter.scene_type=="deck" and args.has("card_id"):guide.targets=[{"card_id":args.card_id}]
 nodes.append({"type":"task","guide":guide,"task":{"timing":"action","action":action,"allowed_actions":Actions.ALLOWED.duplicate(),"success":success},"next":"$complete"})
 cursor=actions.size();points.append(capture_point());changed.emit()

func load_nodes(value: Array,apply_action: Callable) -> String:
 recording=false;replaying=false;actions=[];nodes=[];points=[capture_point()];cursor=0
 for node in value:
  var action=node.task.action
  var reason=apply_action.call(action)
  if not reason.is_empty():return reason
  actions.append(action.duplicate(true));nodes.append(node.duplicate(true));points.append(capture_point())
 seek(0);return verify()

func seek(index: int) -> bool:
 if index<0 or index>=points.size():return false
 recording=false;replaying=false;cursor=index;adapter.restore(points[index])
 if restore_ui.is_valid():restore_ui.call(points[index].get("recording_ui",{}))
 changed.emit();return true

func resume_record(index: int=-1) -> bool:
 if index<0:index=cursor
 if not seek(index):return false
 actions.resize(index);nodes.resize(index);points.resize(index+1)
 recording=true;changed.emit();return true

func undo() -> bool:
 if replaying or actions.is_empty() or cursor==0:return false
 return resume_record(maxi(0,cursor-1))

func reset_setup():
 if not points.is_empty():seek(0)
 recording=false;actions=[];nodes=[];points=[];cursor=0;changed.emit()

func finish():
 if not points.is_empty():seek(actions.size())
 recording=false;changed.emit()

func start_replay() -> String:
 if recording:finish()
 if actions.is_empty():return "请先录制至少一个功能操作。"
 if cursor>=actions.size():seek(0)
 replaying=true;replay_delay=0.0;changed.emit();return ""

func pause_replay():
 replaying=false;changed.emit()

func tick(delta: float,_busy: bool=false) -> String:
 if not replaying:return ""
 replay_delay-=delta
 if replay_delay>0:return ""
 seek(cursor+1)
 replaying=cursor<actions.size();replay_delay=0.7;changed.emit();return ""

func verify() -> String:
 if nodes.is_empty():return "请先录制至少一个功能操作。"
 var check=Config.new();check.definitions=definitions
 var steps=validation_steps.duplicate(true)
 for i in range(nodes.size()):steps["recorded_"+str(i)]=nodes[i]
 for i in range(nodes.size()):check.step(nodes[i],"steps.recorded_"+str(i),steps,validation_scenarios)
 return "\n".join(check.errors)
