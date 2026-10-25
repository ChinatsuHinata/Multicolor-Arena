extends Node
signal changed
const Client=preload("res://scripts/community_client.gd")
const Config=preload("res://scripts/tutorial/config.gd")
var app
var permissions: Dictionary={}
var permission_token=""
var pending_reviews=0
var syncing=false
var status=""
var manifest: Dictionary={}
var pending: Array=[]
var next_manifest: Dictionary={}
var directory="user://online_tutorials"

func _ready():
 directory=app.settings_path.get_base_dir().path_join("online_tutorials")
 var saved=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("manifest.json"))) if FileAccess.file_exists(directory.path_join("manifest.json")) else null
 if saved is Dictionary:manifest=saved

func allowed(role: String) -> bool:
 return not app.account_token.is_empty() and permission_token==app.account_token and permissions.get(role,false)

func request(payload: Dictionary,callback: Callable):
 var client=Client.new();add_child(client);client.server_url=app.tournament_server_url
 var token=app.account_token
 client.finished.connect(func(answer):
  client.queue_free()
  if not callback.is_valid():return
  if token!=app.account_token:callback.call({"ok":false,"message":"账号已变化，请重试"});return
  if answer.get("permissions") is Dictionary:
   permission_token=token;permissions=answer.permissions;pending_reviews=int(answer.get("pending_reviews",0));changed.emit()
  callback.call(answer))
 client.request(payload,token)

func paths() -> Array:
 var result=[]
 for entry in manifest.values():
  if entry is Dictionary and entry.get("path") is String and FileAccess.file_exists(entry.path):result.append(entry.path)
 return result

func revision(id: String) -> int:
 return int(manifest.get(id,{}).get("revision",0))

func sync_tutorials():
 if syncing:return
 syncing=true;status="正在扫描线上教程包…";changed.emit()
 request({"action":"manifest"},func(answer):
  if not answer.get("ok",false):finish_sync(str(answer.get("message","同步失败，继续使用已缓存教程")));return
  pending=[];next_manifest={}
  for entry in answer.get("lessons",[]):
   if not entry is Dictionary or not safe_id(str(entry.get("id",""))) or not safe_digest(str(entry.get("digest",""))):finish_sync("线上教程目录无效");return
   var old=manifest.get(entry.id,{})
   if old.get("digest","")==entry.digest and FileAccess.file_exists(str(old.get("path",""))):next_manifest[entry.id]=old
   else:pending.append(entry)
  download_next())

func safe_id(value: String) -> bool:
 var pattern=RegEx.new();pattern.compile("^[A-Za-z0-9_-]{1,80}$")
 return pattern.search(value)!=null

func safe_digest(value: String) -> bool:
 var pattern=RegEx.new();pattern.compile("^[a-f0-9]{64}$")
 return pattern.search(value)!=null

func download_next():
 if pending.is_empty():
  if not write_atomic(directory.path_join("manifest.json"),JSON.stringify(next_manifest)):finish_sync("无法保存教程目录，保留原有教程包");return
  manifest=next_manifest.duplicate(true);app.load_tutorial_catalog();finish_sync("线上教程已同步");return
 var entry=pending.pop_front()
 status="正在同步："+str(entry.get("title",entry.id));changed.emit()
 request({"action":"lesson","id":entry.id},func(answer):
  if not answer.get("ok",false):finish_sync(str(answer.get("message","教程下载失败")));return
  var source=str(answer.get("document_text",""))
  if source.sha256_text()!=entry.digest or int(answer.get("revision",0))!=int(entry.revision):finish_sync("教程在同步期间更新，请重新打开教程重试");return
  var document=JSON.parse_string(source)
  var checked=Config.new().validate(document,app.Store.CARDS)
  if not checked.ok:finish_sync("线上教程未通过本机校验，保留已安装版本："+str(entry.id));return
  var path=directory.path_join(str(entry.id)+"_"+str(entry.digest)+".json")
  if not write_atomic(path,source):finish_sync("无法写入教程包，保留已安装版本");return
  next_manifest[entry.id]={"path":path,"revision":entry.revision,"digest":entry.digest}
  download_next())

func finish_sync(message: String):
 syncing=false;status=message;changed.emit()

func write_atomic(path: String,content: String) -> bool:
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))!=OK:return false
 var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:return false
 file.store_string(content);file.flush();var error=file.get_error();file.close()
 return error==OK and DirAccess.rename_absolute(path+".tmp",path)==OK
