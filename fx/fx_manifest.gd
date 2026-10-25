extends RefCounted
## Reads and validates one JSON manifest per effect in fx/definitions/.
## A manifest is the only file that names an effect; everything else in fx/
## is discovered from it. Bad manifests are reported, never silently skipped.

const ROOT="res://fx/definitions"
const MODULE_ROOT="res://fx/modules/"
const CATEGORIES=["entrance","foil","spell"]
const OPTIONAL_KEYS=["name","description","shop_product","free","priority","budget_ms","asset_dir","params","notes"]

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
