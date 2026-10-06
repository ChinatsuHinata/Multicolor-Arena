extends RefCounted
## Durable entry checkpoints let a directory revisit real task/scene state.
const VERSION=1
var directory="user://tutorial_progress"
var records: Dictionary={}
var last_error=""
var signature_course: Dictionary={}
var signature_value=""

static func ordered_steps(data: Dictionary) -> Array:
 var result: Array=[]
 var id=str(data.start_step)
 while data.steps.has(id) and id not in result:
  result.append(id);id=str(data.steps[id].next)
 # Failure branches are listed too, but only actual visits unlock them.
 for other in data.steps:
  if other not in result:result.append(other)
 return result

func signature(data: Dictionary) -> String:
 if not is_same(signature_course,data):
  signature_course=data
  # JSON-loaded numbers and authoring dictionaries share the same fingerprint.
  signature_value=JSON.stringify(JSON.parse_string(JSON.stringify(data))).sha256_text()
 return signature_value

func course_directory(data: Dictionary) -> String:
 return directory.path_join(str(data.id).sha256_text())

func step_path(data: Dictionary,id: String) -> String:
 return course_directory(data).path_join(id.sha256_text()+".bin")

func record(data: Dictionary) -> Dictionary:
 var key=course_directory(data)+signature(data)
 if records.has(key):return records[key]
 var value=JSON.parse_string(FileAccess.get_file_as_string(course_directory(data).path_join("index.json"))) if FileAccess.file_exists(course_directory(data).path_join("index.json")) else null
 if not value is Dictionary or value.get("version")!=VERSION or value.get("signature")!=signature(data) or not value.get("read") is Array:
  value={"version":VERSION,"signature":signature(data),"read":[]}
 value.read=value.read.filter(func(id):return id is String and data.steps.has(id) and FileAccess.file_exists(step_path(data,id)))
 records[key]=value
 return value

func has_read(data: Dictionary,id: String) -> bool:
 return id in record(data).read

func can_open(data: Dictionary,id: String) -> bool:
 return data.steps.has(id) and (id==data.start_step or has_read(data,id))

func latest_step(data: Dictionary) -> String:
 var ids=ordered_steps(data)
 for i in range(ids.size()-1,-1,-1):
  if has_read(data,ids[i]):return ids[i]
 return data.start_step

func save(data: Dictionary,id: String,snapshot: Dictionary) -> bool:
 last_error=""
 if not data.steps.has(id) or snapshot.get("step")!=id or snapshot.get("course_id")!=data.id:return false
 var value=record(data)
 # Keep valid entrances when backtracking; rereading repairs a damaged file.
 if id in value.read and not self.snapshot(data,id,{}).is_empty():return true
 last_error=""
 var folder=course_directory(data)
 if DirAccess.make_dir_recursive_absolute(folder)!=OK:return fail("无法创建教程进度目录。")
 var state=portable(snapshot)
 var path=step_path(data,id)
 var file=FileAccess.open_compressed(path+".tmp",FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
 if file==null:return fail("无法保存教程步骤。")
 file.store_var({"version":VERSION,"signature":signature(data),"snapshot":state})
 file.flush()
 var error=file.get_error();file.close()
 if error!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK:return fail("无法写入教程步骤。")
 var updated=value.duplicate(true)
 if id not in updated.read:updated.read.append(id)
 file=FileAccess.open(folder.path_join("index.json.tmp"),FileAccess.WRITE)
 if file==null:return fail("无法保存教程已读记录。")
 file.store_string(JSON.stringify(updated));file.flush();error=file.get_error();file.close()
 if error!=OK or DirAccess.rename_absolute(folder.path_join("index.json.tmp"),folder.path_join("index.json"))!=OK:return fail("无法写入教程已读记录。")
 records[folder+signature(data)]=updated
 return true

func fail(reason: String) -> bool:
 last_error=reason
 return false

func snapshot(data: Dictionary,id: String,cards: Dictionary) -> Dictionary:
 last_error=""
 if not has_read(data,id):return {}
 var file=FileAccess.open_compressed(step_path(data,id),FileAccess.READ)
 var value=file.get_var(false) if file!=null else null
 if file!=null:file.close()
 if not value is Dictionary or value.get("version")!=VERSION or value.get("signature")!=signature(data) or not value.get("snapshot") is Dictionary:
  fail("教程步骤记录无法读取，请从头阅读。");return {}
 var state=value.snapshot
 if not valid_state(data,id,state):
  fail("教程步骤记录已失效，请从头阅读。");return {}
 supply_definitions(state.adapter,cards)
 for scenario in state.get("scenario_states",{}).values():supply_definitions(scenario.adapter,cards)
 return state

func valid_state(data: Dictionary,id: String,state: Dictionary) -> bool:
 if state.get("course_id")!=data.id or state.get("step")!=id:return false
 for key in ["adapter","opponent","sequence","practice","scenario_states","presentation"]:
  if not state.get(key) is Dictionary:return false
 for key in ["completed_steps","events"]:
  if not state.get(key) is Array:return false
 if not state.get("epoch") is int:return false
 if not valid_adapter(data,state.adapter):return false
 for scene in state.scenario_states.values():
  if not scene is Dictionary or not scene.get("adapter") is Dictionary or not scene.get("opponent") is Dictionary:return false
  if not valid_adapter(data,scene.adapter):return false
 for id_done in state.completed_steps:
  if not id_done is String or not data.steps.has(id_done):return false
 for item in state.events:
  if not item is Dictionary or not item.get("epoch") is int or not item.get("event") is Dictionary:return false
 for key in ["config","counts"]:
  if not state.opponent.get(key) is Dictionary:return false
 return state.opponent.get("events") is Array

func valid_adapter(data: Dictionary,adapter: Dictionary) -> bool:
 if not data.scenarios.has(adapter.get("scenario_id","")):return false
 for key in ["game","aliases","components","scene_config","ui_deck","last_ui_action","opponent"]:
  if not adapter.get(key) is Dictionary:return false
 if adapter.get("scene_type") not in ["deck","in_game","battlefield"]:return false
 var game=adapter.game
 if game.is_empty():return adapter.scene_type!="battlefield"
 return game.get("nodes") is Array and game.get("root") is Dictionary and game.get("plain") is Dictionary

func portable(snapshot: Dictionary) -> Dictionary:
 var state=snapshot.duplicate()
 state.erase("history");state.erase("sequence_origin")
 state.adapter=portable_adapter(state.adapter)
 state.scenario_states=state.scenario_states.duplicate()
 for id in state.scenario_states:
  var scene=state.scenario_states[id].duplicate()
  scene.adapter=portable_adapter(scene.adapter);state.scenario_states[id]=scene
 return state

func portable_adapter(adapter: Dictionary) -> Dictionary:
 var result=adapter.duplicate();result.game=result.game.duplicate()
 # Definitions come from the current card database when reopening a step.
 result.game.erase("definitions")
 return result

func supply_definitions(adapter: Dictionary,cards: Dictionary):
 if not adapter.game.is_empty():adapter.game.definitions=cards
