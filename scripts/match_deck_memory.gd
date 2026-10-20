extends RefCounted
## Store identifiers rather than collection indices; portable across restarts.
const Store=preload("res://scripts/deck_store.gd")

static func path() -> String:return Store.folder().path_join(".match-deck.cfg")

static func selected(account: String) -> String:
 var config=ConfigFile.new()
 if config.load(path())!=OK:return ""
 return str(config.get_value("matching",account.to_lower() if not account.is_empty() else "@local",""))

static func remember(account: String,id: String) -> String:
 var config=ConfigFile.new()
 if FileAccess.file_exists(path()) and config.load(path())!=OK:return "无法读取上次匹配卡组记录。"
 config.set_value("matching",account.to_lower() if not account.is_empty() else "@local",id)
 var error=Store.Paths.initialize()
 if not error.is_empty():return error
 if config.save(path()+".tmp")!=OK:return "无法保存上次匹配卡组。"
 if DirAccess.rename_absolute(path()+".tmp",path())!=OK:return "无法替换上次匹配卡组记录。"
 return ""
