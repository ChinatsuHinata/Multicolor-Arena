extends Node
## Native VIEW requests live in app cache until the main UI accepts or rejects them.
signal replay_received(path: String,display_name: String)
signal import_failed(message: String)
const Archive=preload("res://scripts/replay_archive.gd")
var directory=""
var seen={}
var timer: Timer

func start(test_directory: String="") -> bool:
 if timer!=null:return true
 directory=test_directory
 if directory.is_empty():
  if OS.get_name()!="Android" or not Engine.has_singleton("AndroidRuntime"):return false
  var runtime=Engine.get_singleton("AndroidRuntime")
  var context=runtime.getApplicationContext()
  directory=str(context.getCacheDir().getAbsolutePath()).path_join("replay-inbox")
 directory=directory.simplify_path()
 process_mode=Node.PROCESS_MODE_ALWAYS
 timer=Timer.new();timer.wait_time=0.5;timer.process_mode=Node.PROCESS_MODE_ALWAYS
 add_child(timer);timer.timeout.connect(poll);timer.start()
 call_deferred("poll")
 return true

func request_id(filename: String) -> String:
 var id=filename.trim_suffix(".json")
 return id if filename.ends_with(".json") and id.length()==32 and id.is_valid_hex_number(false) else ""

func poll():
 if directory.is_empty() or not DirAccess.dir_exists_absolute(directory):return
 var files=Array(DirAccess.get_files_at(directory));files.sort()
 for filename in files:
  var id=request_id(filename)
  if id.is_empty() or seen.has(id):continue
  seen[id]=true
  var request=directory.path_join(filename)
  var file=FileAccess.open(request,FileAccess.READ)
  if file==null:
   seen.erase(id);continue
  if file.get_length()>16384:
   file.close();DirAccess.remove_absolute(request);import_failed.emit("回放导入信息无效。");continue
  var value=JSON.parse_string(file.get_as_text());file.close()
  if not value is Dictionary:
   DirAccess.remove_absolute(request);import_failed.emit("回放导入信息无效。");continue
  if value.has("error"):
   DirAccess.remove_absolute(request);import_failed.emit(str(value.error).left(240));continue
  if value.get("file","")!=id+".mreply":
   DirAccess.remove_absolute(request);import_failed.emit("回放缓存路径无效。");continue
  var path=directory.path_join(id+".mreply")
  var replay=FileAccess.open(path,FileAccess.READ)
  if replay==null or replay.get_length()>Archive.MAX_FILE or replay.get_length()<Archive.MAGIC.length():
   if replay!=null:replay.close()
   acknowledge(path);import_failed.emit("回放文件缺失或超过容量限制。");continue
  var valid=replay.get_buffer(Archive.MAGIC.length()).get_string_from_utf8()==Archive.MAGIC;replay.close()
  if not valid:
   acknowledge(path);import_failed.emit("此文件不是有效的极彩回放。");continue
  var display_name=str(value.get("name","回放.mreply")).get_file().left(180)
  replay_received.emit(path,display_name)

func acknowledge(path: String):
 var clean=path.simplify_path()
 if directory.is_empty() or clean.get_base_dir()!=directory:return
 var id=request_id(clean.get_file().trim_suffix(".mreply")+".json")
 if id.is_empty() or clean.get_file()!=id+".mreply":return
 if FileAccess.file_exists(clean):DirAccess.remove_absolute(clean)
 var request=directory.path_join(id+".json")
 if FileAccess.file_exists(request):DirAccess.remove_absolute(request)
 seen.erase(id)
