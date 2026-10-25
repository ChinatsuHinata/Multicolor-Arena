extends RefCounted
## Reads and validates one JSON manifest per effect in fx/definitions/.
## A manifest is the only file that names an effect; everything else in fx/
## is discovered from it. Bad manifests are reported, never silently skipped.

const ROOT="res://fx/definitions"
const MODULE_ROOT="res://fx/modules/"
const CATEGORIES=["entrance","foil","spell"]
## 入场时间点：before 在单位牌离开堆叠、正飞向战场时开播；after 在卡牌落场后开播。
const TIMINGS=["before","after"]
## 入场持续：turn 允许模块自己决定持续到回合结束（hold_until_turn_end）。
const SUSTAINS=["none","turn"]
const ORIGINS=["none","character"]
const DESTINATIONS=["none","spell_target"]
const OPTIONAL_KEYS=["name","description","shop_product","free","priority","budget_ms","asset_dir","params","notes","cards","timing","flight","flight_ms","flight_ease","character_spell","character","origin","destination","hold_ms","sustain"]

static func load_all(root: String=ROOT) -> Dictionary:
 var effects: Dictionary={}
 var errors: Array=[]
 var dir=DirAccess.open(root)
 if dir==null:
  # An empty catalog has no definitions folder in a clean checkout or export.
  if root!=ROOT or DirAccess.dir_exists_absolute(root):
   errors.append({"file":root,"reason":"manifest folder could not be opened"})
  return {"effects":effects,"errors":errors}
 for file in dir.get_files():
  if not file.ends_with(".json"):continue
  var path=root.path_join(file)
  var data=JSON.parse_string(FileAccess.get_file_as_string(path))
  var reason=validate(data,path)
  if not reason.is_empty():
   errors.append({"file":path,"reason":reason})
   continue
  if effects.has(data.id):
   errors.append({"file":path,"reason":"duplicate id "+str(data.id)})
   continue
  data["source"]=path
  effects[data.id]=data
 return {"effects":effects,"errors":errors}

static func validate(data: Variant,path: String) -> String:
 if not data is Dictionary:return "not a JSON object"
 for key in ["id","category","script"]:
  if not data.get(key) is String or str(data.get(key)).strip_edges().is_empty():return "missing "+key
 var id=str(data.id)
 if not valid_id(id):return "id must be 2-40 chars of a-z, 0-9 and _"
 if id!=path.get_file().get_basename():return "id must match the file name"
 if not CATEGORIES.has(str(data.category)):return "category must be one of "+", ".join(CATEGORIES)
 var script=str(data.script)
 if not script.begins_with(MODULE_ROOT):return "script must live under "+MODULE_ROOT
 if not script.ends_with(".gd"):return "script must be a .gd file"
 if not FileAccess.file_exists(script):return "script not found: "+script
 if data.has("budget_ms") and (not data.budget_ms is float and not data.budget_ms is int):return "budget_ms must be a number"
 if data.has("budget_ms") and (float(data.budget_ms)<50.0 or float(data.budget_ms)>5000.0):return "budget_ms must be 50-5000"
 if data.has("priority") and (not data.priority is float and not data.priority is int):return "priority must be a number"
 if data.has("free") and not data.free is bool:return "free must be a boolean"
 if data.has("shop_product") and not data.shop_product is String:return "shop_product must be a string"
 if data.has("params") and not data.params is Dictionary:return "params must be an object"
 if data.has("asset_dir") and not str(data.asset_dir).begins_with("res://fx/assets/"):return "asset_dir must live under res://fx/assets/"
 if data.has("cards"):
  if not data.cards is Array or data.cards.is_empty():return "cards must be a non-empty array of card ids"
  for card in data.cards:
   if not card is String or str(card).strip_edges().is_empty():return "cards must hold card id strings"
 if data.has("flight"):
  if str(data.category)!="entrance":return "flight only applies to entrance effects"
  if not data.flight is String or not ["none","track","proxy"].has(data.flight):return "flight must be one of none, track, proxy"
  if data.flight in ["track","proxy"] and data.get("timing","after")!="before":return "flight requires timing before"
 if data.has("flight_ms"):
  if data.get("flight","none")!="proxy":return "flight_ms requires flight proxy"
  if (not data.flight_ms is float and not data.flight_ms is int) or not (float(data.flight_ms)>=200.0 and float(data.flight_ms)<=2000.0):return "flight_ms must be between 200 and 2000"
 if data.has("flight_ease"):
  if data.get("flight","none")!="proxy":return "flight_ease requires flight proxy"
  if not ["cubic_in_out","sine_in_out","linear"].has(data.flight_ease):return "flight_ease must be one of cubic_in_out, sine_in_out, linear"
 if data.has("timing"):
  if str(data.category)!="entrance":return "timing only applies to entrance effects"
  if not data.timing is String or not TIMINGS.has(str(data.timing)):return "timing must be one of "+", ".join(TIMINGS)
 if data.has("sustain"):
  if str(data.category)!="entrance":return "sustain only applies to entrance effects"
  if not data.sustain is String or not SUSTAINS.has(str(data.sustain)):return "sustain must be one of "+", ".join(SUSTAINS)
 for key in ["character_spell","character","origin","destination","hold_ms"]:
  if data.has(key) and str(data.category)!="spell":return key+" only applies to spell effects"
 if data.has("character_spell") and not data.character_spell is bool:return "character_spell must be a boolean"
 if data.has("character") and not data.character is String:return "character must be a string"
 if data.has("origin") and (not data.origin is String or not ORIGINS.has(data.origin)):return "origin must be one of none, character"
 if data.has("destination") and (not data.destination is String or not DESTINATIONS.has(data.destination)):return "destination must be one of none, spell_target"
 if data.has("hold_ms") and (not data.hold_ms is float and not data.hold_ms is int or float(data.hold_ms)<0.0 or float(data.hold_ms)>5000.0):return "hold_ms must be a number 0-5000"
 if data.get("origin","none")=="character" and data.get("character_spell",false)!=true:return "origin character requires character_spell"
 return ""

static func valid_id(id: String) -> bool:
 if id.length()<2 or id.length()>40:return false
 for index in range(id.length()):
  var character=id[index]
  if character>="a" and character<="z":continue
  if character>="0" and character<="9":continue
  if character=="_":continue
  return false
 return true
