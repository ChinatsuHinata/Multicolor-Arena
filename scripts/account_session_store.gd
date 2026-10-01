extends RefCounted
## The remembered bearer token is stored in the current OS user's app data.
const DEFAULT_PATH="user://account_session.json"

static func valid_token(token: String) -> bool:
 if token.length()!=64:return false
 for ch in token:
  if not ch in "0123456789abcdef":return false
 return true

static func load_token(device: String,path: String=DEFAULT_PATH) -> String:
 if not FileAccess.file_exists(path):return ""
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or data.get("device","")!=device:return ""
 var token=data.get("remember_token","")
 return token if token is String and valid_token(token) else ""

static func save_token(device: String,token: String,path: String=DEFAULT_PATH) -> bool:
 if not valid_token(token):return false
 var file=FileAccess.open(path,FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify({"device":device,"remember_token":token}))
 file.flush()
 var ok=file.get_error()==OK
 file.close()
 return ok

static func clear(path: String=DEFAULT_PATH) -> void:
 if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
