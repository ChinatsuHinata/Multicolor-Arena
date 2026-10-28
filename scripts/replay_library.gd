extends RefCounted
## Only history/ is managed by the rolling limit. Existing root files are kept.
const Paths=preload("res://scripts/portable_paths.gd")
const PlayerNameDisplay=preload("res://scripts/player_name_display.gd")
const HISTORY_LIMIT=20

static func folder(history: bool=false) -> String:
 var base=Paths.root().path_join("replay")
 return base.path_join("history") if history else base

static func initialize() -> String:
 var error=Paths.initialize()
 if not error.is_empty():return error
 var status=DirAccess.make_dir_recursive_absolute(folder(true))
 return "无法创建最近历史目录："+error_string(status) if status!=OK else ""

static func entries(history: bool=false) -> Array:
 var result=[]
 for filename in DirAccess.get_files_at(folder(history)):
  if filename.get_extension().to_lower()!="mreply":continue
  var path=folder(history).path_join(filename)
  var caption=filename
  # Automatically recorded filenames start with a sortable completion time.
  if filename.length()>21 and filename.left(20).is_valid_int() and filename[20]=="_":caption=filename.substr(21)
  result.append({"path":path,"filename":filename,"caption":PlayerNameDisplay.replay_filename(caption),"modified":FileAccess.get_modified_time(path)})
 result.sort_custom(func(a,b):
  if history:return a.filename>b.filename
  return a.filename>b.filename if a.modified==b.modified else a.modified>b.modified)
 return result

static func prune_history() -> String:
 var files=entries(true)
 for i in range(HISTORY_LIMIT,files.size()):
  var status=DirAccess.remove_absolute(files[i].path)
  if status!=OK:return "无法清理最早的历史录像："+error_string(status)
 return ""

static func record_finished(archive) -> Dictionary:
 if not archive.finished:return {"error":"对局尚未结束"}
 if not archive.history_path.is_empty():return {"path":archive.history_path}
 var error=initialize()
 if not error.is_empty():return {"error":error}
 # Keep a stable destination for retries and repeated completion notifications.
 if not archive.metadata.has("history_file"):
  archive.metadata.history_file="%020d_%s_%s.mreply" % [int(Time.get_unix_time_from_system()*1000000),archive.title(),Crypto.new().generate_random_bytes(4).hex_encode()]
 var filename=str(archive.metadata.history_file).get_file()
 if filename.get_extension().to_lower()!="mreply":return {"error":"历史录像文件名无效"}
 var result=archive.save(folder(true).path_join(filename))
 if result.has("error"):return result
 archive.history_path=result.path
 var warning=prune_history()
 if not warning.is_empty():result.warning=warning
 return result

static func keep(path: String) -> Dictionary:
 var error=initialize()
 if not error.is_empty():return {"error":error}
 var destination=folder().path_join(path.get_file())
 if FileAccess.file_exists(destination):
  if FileAccess.get_sha256(path)==FileAccess.get_sha256(destination):return {"path":destination}
  destination=folder().path_join(path.get_file().get_basename()+"_"+Crypto.new().generate_random_bytes(4).hex_encode()+".mreply")
 return export_file(path,destination)

static func export_file(source: String,destination: String) -> Dictionary:
 if not FileAccess.file_exists(source):return {"error":"录像文件已不存在，请刷新列表。"}
 # Android SAF returns an opaque document URI, not a directory and filename.
 # FileAccess can write it; appending extensions or renaming siblings cannot.
 if destination.begins_with("content://"):return write_document(source,destination)
 if destination.get_extension().to_lower()!="mreply":destination+=".mreply"
 if ProjectSettings.globalize_path(source).simplify_path()==ProjectSettings.globalize_path(destination).simplify_path():return {"path":destination}
 # Copy bytes verbatim: exporting must also work for archives we cannot play.
 if not DirAccess.dir_exists_absolute(destination.get_base_dir()):return {"error":"导出目录不存在。"}
 var temporary=destination+"."+Crypto.new().generate_random_bytes(4).hex_encode()+".tmp"
 var status=DirAccess.copy_absolute(source,temporary)
 if status==OK:status=DirAccess.rename_absolute(temporary,destination)
 if status!=OK:
  if FileAccess.file_exists(temporary):DirAccess.remove_absolute(temporary)
  return {"error":"无法导出录像："+error_string(status)}
 return {"path":destination}

static func write_document(source: String,destination: String) -> Dictionary:
 var input=FileAccess.open(source,FileAccess.READ)
 if input==null:return {"error":"无法读取要导出的录像。"}
 var output=FileAccess.open(destination,FileAccess.WRITE)
 if output==null:return {"error":"无法写入所选文件："+error_string(FileAccess.get_open_error())}
 while input.get_position()<input.get_length():
  var count=mini(1024*1024,input.get_length()-input.get_position())
  var bytes=input.get_buffer(count)
  if bytes.size()!=count:return {"error":"读取录像时发生错误，导出未完成。"}
  output.store_buffer(bytes)
  if output.get_error()!=OK:return {"error":"写入所选文件失败，导出未完成。"}
 output.flush()
 if output.get_error()!=OK:return {"error":"写入所选文件失败，导出未完成。"}
 output.close();input.close()
 return {"path":destination}
