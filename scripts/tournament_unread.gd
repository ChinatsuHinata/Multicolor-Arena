extends Node
## Read receipts belong to each local account; only a complete list replaces the badge snapshot.
signal changed
const Client=preload("res://scripts/tournament_client.gd")
var path="user://tournament_reads.json"
var receipts: Dictionary={}
var account=""
var token=""
var server_url=""
var known_ids: Dictionary={}
var pending_ids: Dictionary={}
var client
var last_error=""

func initialize(storage_path: String):
 path=storage_path;receipts={};last_error=""
 if not FileAccess.file_exists(path):return
 var saved=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not saved is Dictionary or saved.get("schema")!=1 or not saved.get("accounts") is Dictionary:return
 for username in saved.accounts:
  if not username is String or not saved.accounts[username] is Array:continue
  var ids: Dictionary={}
  for id in saved.accounts[username]:
   if id is String and id.is_valid_int() and int(id)>0:ids[id]=true
  receipts[username]=ids

func set_session(username: String,session_token: String,url: String):
 var next_account=username.to_lower() if not session_token.is_empty() else ""
 if account==next_account and token==session_token and server_url==url:return
 cancel_request()
 if account!=next_account or server_url!=url:known_ids={}
 account=next_account;token=session_token;server_url=url
 changed.emit()

func unread_count() -> int:
 if account.is_empty() or token.is_empty():return 0
 var read_ids: Dictionary=receipts.get(account,{})
 var count=0
 for id in known_ids:
  if not read_ids.has(id):count+=1
 return count

func mark_read(id: int):
 if account.is_empty() or token.is_empty() or id<=0:return
 var read_ids: Dictionary=receipts.get(account,{})
 var key=str(id)
 if read_ids.has(key):return
 read_ids[key]=true;receipts[account]=read_ids
 save();changed.emit()

func save() -> bool:
 var accounts: Dictionary={}
 for username in receipts:accounts[username]=receipts[username].keys()
 var directory=ProjectSettings.globalize_path(path).get_base_dir()
 if DirAccess.make_dir_recursive_absolute(directory)!=OK:
  last_error="比赛已读记录目录无法创建。";push_warning(last_error);return false
 var file=FileAccess.open(path,FileAccess.WRITE)
 if file==null:
  last_error="比赛已读记录无法保存。";push_warning(last_error);return false
 file.store_string(JSON.stringify({"schema":1,"accounts":accounts}));file.close()
 last_error="";return true

func refresh():
 if account.is_empty() or token.is_empty() or is_instance_valid(client):return
 pending_ids={};fetch_page(0)

func fetch_page(index: int):
 client=Client.new();add_child(client);client.server_url=server_url
 client.finished.connect(receive.bind(index))
 client.request({"action":"list","page":index},token)

func receive(answer: Dictionary,index: int):
 if is_instance_valid(client):client.queue_free();client=null
 if not answer.get("ok",false) or not answer.get("tournaments") is Array:
  pending_ids={};return
 for entry in answer.tournaments:
  if entry is Dictionary and int(entry.get("id",0))>0 and entry.get("phase","")!="deleted":pending_ids[str(int(entry.id))]=true
 if index+1<int(answer.get("pages",1)):
  fetch_page(index+1);return
 known_ids=pending_ids;pending_ids={};changed.emit()

func cancel_request():
 if is_instance_valid(client):
  client.close();client.queue_free();client=null
 pending_ids={}

func _exit_tree():cancel_request()
