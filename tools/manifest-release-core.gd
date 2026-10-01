extends SceneTree
## Reads the actual exported PCK, rather than the source tree.

const DATA_DIRS=["cards/", "data/", "net/"]
const SCRIPT_DIRS=["scripts/rules/", "scripts/ai/"]
const CORE_FILES=["scripts/card_database.gdc", "scripts/deck_store.gdc", "scripts/deck_rule_set.gdc", "scripts/account_client.gdc", "scripts/account_session_store.gdc", "scripts/deck_plaza_client.gdc", "scripts/deck_plaza.gdc", "scripts/main.gdc"]
var failed=false

func _initialize():
 var data={}
 var scripts=[]
 _collect("res://",data,scripts)
 scripts.sort()
 print("CORE_MANIFEST: "+JSON.stringify({"version":str(ProjectSettings.get_setting("application/config/version","")),"data":data,"scripts":scripts}))
 quit(0 if not failed and not data.is_empty() and not scripts.is_empty() else 1)

func _collect(path: String, data: Dictionary, scripts: Array):
 var directory=DirAccess.open(path)
 if directory==null:
  push_error("Cannot inspect exported PCK: "+path)
  failed=true
  return
 for name in directory.get_files():
  var relative=(path+name).trim_prefix("res://")
  if _is_data(relative):data[relative]=FileAccess.get_sha256(path+name)
  elif _is_script(relative):scripts.append(relative)
 for name in directory.get_directories():
  _collect(path+name+"/",data,scripts)

func _is_data(relative: String) -> bool:
 if relative=="data/account_public.pem":return true
 if not relative.ends_with(".json"):return false
 for directory in DATA_DIRS:
  if relative.begins_with(directory):return true
 return false

func _is_script(relative: String) -> bool:
 if relative in CORE_FILES:return true
 if not relative.ends_with(".gdc"):return false
 for directory in SCRIPT_DIRS:
  if relative.begins_with(directory):return true
 return false
