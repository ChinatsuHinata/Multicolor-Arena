extends RefCounted
## Desktop portable files live beside the executable; Android uses writable app data.
static var root_override=""
static func root() -> String:
 if not root_override.is_empty():return root_override
 if OS.get_name()=="Android":return ProjectSettings.globalize_path("user://")
 if OS.has_feature("editor"):return ProjectSettings.globalize_path("res://")
 return OS.get_executable_path().get_base_dir()
static func initialize() -> String:
 for folder in ["deck","replay"]:
  var error=DirAccess.make_dir_recursive_absolute(root().path_join(folder))
  if error!=OK:return "无法创建 "+folder+" 文件夹："+error_string(error)+"。请将游戏放在可写入的文件夹。"
 return ""
