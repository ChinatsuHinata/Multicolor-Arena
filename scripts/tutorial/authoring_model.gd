extends RefCounted
## Editable schema data only; engine instances and editor layout never enter JSON.
const Config=preload("res://scripts/tutorial/config.gd")
const Adapter=preload("res://scripts/tutorial/game_adapter.gd")
const Progress=preload("res://scripts/tutorial/progress.gd")
const LOCAL_DIR="user://tutorials"
var data: Dictionary={}
var path=""
var saved_text=""
var undo_stack: Array=[]
var redo_stack: Array=[]

static func battle() -> Dictionary:
 return {"type":"battlefield","seed":42,"turn":1,"phase":"main","active":0,"priority":0,"players":[
  {"name":"学员","life":20,"leader":{"card_id":"70","alias":"student_leader"},"deck_order":[{"card_id":"53"}],"hand":[],"field":[],"palette":[]},
  {"name":"教程对手","life":20,"leader":{"card_id":"70","alias":"enemy_leader"},"deck_order":[{"card_id":"53"}],"hand":[],"field":[],"palette":[]}],"opponent":{"strategy":"paused","auto_response":true}}

static func deck() -> Dictionary:
 return {"name":"教学卡组","leader":"70","main":["53"],"side":[],"rule_set":"official"}

func fresh():
 data={"schema_version":1,"id":"lesson_"+str(Time.get_unix_time_from_system()).get_slice(".",0),"title":"新战斗任务","category":"beginner","initial_scenario":"scene_1","start_step":"step_1","completion":{"type":"always"},"scenarios":{"scene_1":battle()},"steps":{"step_1":{"type":"info","guide":{"text":"阅读任务说明，然后开始战斗。"},"next":"step_2"},"step_2":{"type":"task","guide":{"text":"击败对方自机。","next_button":"hidden"},"task":{"timing":"state_changed","success":{"type":"life","player":1,"op":"le","value":0},"allow_turn_end":true},"next":"$complete"}}}
 path="";saved_text="";undo_stack.clear();redo_stack.clear()

func checkpoint():
 undo_stack.append(data.duplicate(true))
 if undo_stack.size()>100:undo_stack.pop_front()
 redo_stack.clear()

func undo() -> bool:
 if undo_stack.is_empty():return false
 redo_stack.append(data.duplicate(true));data=undo_stack.pop_back();return true

func redo() -> bool:
 if redo_stack.is_empty():return false
 undo_stack.append(data.duplicate(true));data=redo_stack.pop_back();return true

func dirty() -> bool:
 return JSON.stringify(data)!=saved_text

func unique_id(prefix: String,objects: Dictionary) -> String:
 var index=1
 while objects.has(prefix+str(index)):index+=1
 return prefix+str(index)

func ordered_steps() -> Array:
 return Progress.ordered_steps(data)

func rename_step(id: String,new_id: String) -> String:
 new_id=new_id.strip_edges()
 if not data.steps.has(id):return "节点不存在。"
 if new_id.is_empty():return "节点名称不能为空。"
 if new_id==id:return ""
 if new_id=="$complete":return "该名称保留用于课程完成，请使用其他名称。"
 if new_id!=new_id.validate_node_name() or "\\" in new_id:return "节点名称不能包含 . : @ / \\ \" %。"
 for character in new_id:
  if character.unicode_at(0)<32 or character.unicode_at(0)==127:return "节点名称不能包含换行或控制字符。"
 if data.steps.has(new_id):return "已有同名节点，请使用其他名称。"
 var draft=data.duplicate(true);var steps={}
 # Rebuild in place order so disconnected failure branches keep their positions.
 for key in draft.steps:
  var step=draft.steps[key]
  for edge in ["next","failure"]:
   if step.get(edge)==id:step[edge]=new_id
  steps[new_id if key==id else key]=step
 draft.steps=steps
 if draft.start_step==id:draft.start_step=new_id
 rename_step_conditions(draft,id,new_id)
 var checked=Config.new().validate(draft,preload("res://scripts/deck_store.gd").CARDS)
 if not checked.ok:return "\n".join(checked.errors)
 checkpoint();data=draft
 return ""

func rename_step_conditions(value: Variant,id: String,new_id: String):
 if value is Dictionary:
  if value.get("type")=="steps_completed":
   for i in range(value.steps.size()):
    if value.steps[i]==id:value.steps[i]=new_id
  for child in value.values():rename_step_conditions(child,id,new_id)
 elif value is Array:
  for child in value:rename_step_conditions(child,id,new_id)

func move_step(id: String,index: int) -> String:
 var order=ordered_steps()
 if id not in order or index<0 or index>=order.size():return "教程位置无效。"
 if order.find(id)==index:return ""
 order.erase(id);order.insert(index,id)
 return reorder_steps(order)

func reorder_steps(order: Array) -> String:
 if order.size()!=data.steps.size():return "教程顺序必须包含所有节点。"
 var seen={}
 for id in order:
  if not data.steps.has(id) or seen.has(id):return "教程顺序包含无效或重复节点。"
  seen[id]=true
 if order==ordered_steps():return ""
 # Moving a scene boundary must not silently give another node its tableau.
 var scenes={}
 for id in order:scenes[id]=scene_for(id)
 var draft=data.duplicate(true);var steps={};var inherited=draft.initial_scenario
 for i in range(order.size()):
  var id=order[i];var step=draft.steps[id]
  if not step.has("scenario") and scenes[id]!=inherited:
   step.scenario=scenes[id];step.scenario_mode="reset"
  inherited=step.get("scenario",inherited)
  step.next=order[i+1] if i+1<order.size() else "$complete"
  steps[id]=step
 draft.steps=steps;draft.start_step=order[0]
 var checked=Config.new().validate(draft,preload("res://scripts/deck_store.gd").CARDS)
 if not checked.ok:return "\n".join(checked.errors)
 checkpoint();data=draft
 return ""

func scene_for(step_id: String) -> String:
 return context_for(step_id).scene

func context_for(step_id: String) -> Dictionary:
 # Walk both branches. The editor previews a configured starting tableau;
 # actual carried-over state remains the runtime's responsibility.
 var queue=[[data.start_step,data.initial_scenario,[]]];var seen={}
 while not queue.is_empty():
  var item=queue.pop_front();var id=item[0];var scene_id=item[1]
  if id=="$complete" or not data.steps.has(id):continue
  scene_id=data.steps[id].get("scenario",scene_id)
  var key=id+"@"+scene_id
  if seen.has(key):continue
  seen[key]=true
  if id==step_id:return {"scene":scene_id,"steps":item[2]}
  var prior=item[2].duplicate();prior.append(id)
  for edge in ["next","failure"]:
   if data.steps[id].has(edge):queue.append([data.steps[id][edge],scene_id,prior])
 return {"scene":data.steps.get(step_id,{}).get("scenario",data.initial_scenario),"steps":[]}

func add_step(after: String) -> String:
 checkpoint()
 var id=unique_id("step_",data.steps)
 var next=data.steps[after].get("next","$complete") if data.steps.has(after) else "$complete"
 data.steps[id]={"type":"info","guide":{"text":"新的任务说明。"},"next":next}
 if data.steps.has(after):data.steps[after].next=id
 return id

func remove_step(id: String) -> String:
 if data.steps.size()<=1:return id
 checkpoint()
 var replacement=data.steps[id].get("next","$complete")
 if replacement==id:replacement="$complete"
 data.steps.erase(id)
 for step in data.steps.values():
  for edge in ["next","failure"]:
   if step.get(edge)==id:step[edge]=replacement
 prune_step_conditions(data,id)
 if data.start_step==id:data.start_step=replacement if data.steps.has(replacement) else data.steps.keys()[0]
 return data.start_step

func prune_step_conditions(value: Variant,id: String):
 if value is Dictionary:
  if value.get("type")=="steps_completed":
   value.steps.erase(id)
   if value.steps.is_empty():value.clear();value.type="always"
  for child in value.values():prune_step_conditions(child,id)
 elif value is Array:
  for child in value:prune_step_conditions(child,id)

func new_scene(step_id: String,kind: String,clone_current: bool=true) -> String:
 checkpoint()
 var id=unique_id("scene_",data.scenarios)
 var previous=data.scenarios[scene_for(step_id)]
 var scene: Dictionary
 if kind=="battlefield":scene=previous.duplicate(true) if clone_current and previous.get("type","battlefield")==kind else battle()
 else:
  scene={"type":kind,"deck":previous.deck.duplicate(true) if previous.has("deck") else deck()}
  if kind=="in_game":scene.screen="deck_editor"
 data.scenarios[id]=scene
 data.steps[step_id].scenario=id;data.steps[step_id].scenario_mode="reset"
 return id

func aliases(scene_id: String) -> Array:
 var result=[];var scene=data.scenarios[scene_id]
 for player in scene.get("players",[]):
  if player.leader.has("alias"):result.append(player.leader.alias)
  for zone in ["extra_leaders","deck_order","hand","field","palette","grave","exile"]:
   for card in player.get(zone,[]):
    if card.has("alias"):result.append(card.alias)
 return result

func recording_steps(step_id: String) -> Array:
 # Recover the linear native-task recording, stopping at scene changes or joins.
 if data.steps[step_id].get("task",{}).get("timing")!="action":return []
 var first=step_id;var seen={first:true}
 while not data.steps[first].has("scenario"):
  var parents=data.steps.keys().filter(func(id):return data.steps[id].get("next")==first)
  if parents.size()!=1:break
  var parent=parents[0]
  if seen.has(parent) or data.steps[parent].get("task",{}).get("timing")!="action":break
  first=parent;seen[first]=true
 var ids=[];var current=first
 while data.steps.has(current) and current not in ids:
  var step=data.steps[current]
  if step.get("task",{}).get("timing")!="action" or (current!=first and step.has("scenario")):break
  if current!=first and data.steps.values().filter(func(node):return node.get("next")==current or (node.get("failure")==current and node!=step)).size()>1:break
  ids.append(current);current=step.next
 return ids

func add_card(scene_id: String,who: int,zone: String,card_id: String) -> Dictionary:
 var scene=data.scenarios[scene_id]
 if not scene.get("type","battlefield")=="battlefield":return {}
 var entry={"card_id":card_id}
 var used={}
 for alias in aliases(scene_id):used[alias]=true
 entry.alias=unique_id("entity_",used)
 if card_id=="roster_token_frog":entry.merge({"token_name":"青蛙衍生物","token_value":2,"token_spirit":2})
 var candidate=scene.duplicate(true)
 if zone=="leader":candidate.players[who].leader=entry
 else:
  if not candidate.players[who].has(zone):candidate.players[who][zone]=[]
  candidate.players[who][zone].append(entry)
  normalize_positions(candidate.players[who].get("field",[]))
 var error=check_scene(scene_id,candidate)
 if not error.is_empty():return {"error":error}
 checkpoint();data.scenarios[scene_id]=candidate
 return entry

static func normalize_positions(cards: Array):
 for i in range(cards.size()):
  if cards[i].has("position"):cards[i].position=i

func check_scene(id: String,scene: Dictionary) -> String:
 var validator=Config.new();validator.definitions=preload("res://scripts/deck_store.gd").CARDS
 validator.scenario(scene,"scenarios."+id,data.steps)
 if not validator.errors.is_empty():return "\n".join(validator.errors)
 return Adapter.new().load_scenario(id,scene,validator.definitions)

func validate() -> Dictionary:
 var checked=Config.new().validate(data,preload("res://scripts/deck_store.gd").CARDS)
 if checked.ok:
  for id in data.scenarios:
   var reason=check_scene(id,data.scenarios[id])
   if not reason.is_empty():checked.errors.append(reason)
  checked.ok=checked.errors.is_empty()
 return checked

func load_course(file: String) -> String:
 var checked=Config.new().load_file(file,preload("res://scripts/deck_store.gd").CARDS)
 if not checked.ok:return "\n".join(checked.errors)
 data=checked.data;path=file;saved_text=JSON.stringify(data);undo_stack.clear();redo_stack.clear()
 return ""

func save_course(file: String) -> String:
 var checked=validate()
 if not checked.ok:return "\n".join(checked.errors)
 var target=file if file.ends_with(".json") else file+".json"
 # Write a sibling temporary file then rename. Never truncate the last save.
 var temp=target+".tmp"
 var handle=FileAccess.open(temp,FileAccess.WRITE)
 if handle==null:return "无法写入课程："+error_string(FileAccess.get_open_error())
 handle.store_string(JSON.stringify(data,"  "));handle.flush()
 var write_error=handle.get_error();handle.close()
 if write_error!=OK:return "保存失败："+error_string(write_error)
 var result=DirAccess.rename_absolute(temp,target)
 if result!=OK:return "保存失败："+error_string(result)
 path=target;saved_text=JSON.stringify(data)
 return ""
