extends Node
## The server owns tasks, progress and money; mutations always return its snapshot.
signal changed
signal purchase_finished(ok: bool,message: String)
const Client=preload("res://scripts/account_client.gd")
var account=""
var token=""
var server_url=Client.SERVER_URL
var snapshot: Dictionary={}
var error=""
var client
var rollover_at_ms=0
var rollover_retry_ms=0
var last_settled_match=""
var refresh_pending=false
var purchase_pending=false

func set_session(username: String,session_token: String,url: String):
 var next_account=username.to_lower() if not session_token.is_empty() else ""
 if account==next_account and token==session_token and server_url==url:return
 cancel_request()
 account=next_account;token=session_token;server_url=url;snapshot={};error=""
 rollover_at_ms=0;rollover_retry_ms=0;last_settled_match="";refresh_pending=false
 changed.emit()

func refresh():
 request("tasks")

func purchase(product_id: String,expected_price: int=-1):
 if account.is_empty() or token.is_empty():purchase_finished.emit(false,"请先登录账号");return
 if is_instance_valid(client):return
 purchase_pending=true
 var fields={"q":product_id}
 if expected_price>=0:fields.v=expected_price
 request("shop_buy",fields)

func has_claimable() -> bool:
 if daily_expired():return false
 for task in snapshot.get("daily",{}).get("tasks",[]):
  if task.get("completed",false) and not task.get("claimed",false):return true
 return false

func daily_expired() -> bool:
 return rollover_at_ms>0 and Time.get_ticks_msec()>=rollover_at_ms

func claim(task: Dictionary):
 mutate("task_claim",task)

func reroll(task: Dictionary):
 mutate("task_reroll",task)

func mutate(action: String,task: Dictionary):
 if daily_expired():refresh();return
 request(action,{"d":str(snapshot.get("daily",{}).get("day","")),"l":int(task.get("slot",-1)),"q":str(task.get("id",""))})

func match_completed(match_id: String):
 if match_id.is_empty() or last_settled_match==match_id:return
 last_settled_match=match_id
 if is_instance_valid(client):refresh_pending=true
 else:refresh()

func request(action: String,fields: Dictionary={}):
 if account.is_empty() or token.is_empty() or is_instance_valid(client):return
 error=""
 client=Client.new();add_child(client);client.server_url=server_url
 client.finished.connect(receive)
 changed.emit()
 var data={"a":action,"s":token,"t":int(Time.get_unix_time_from_system()),"n":Crypto.new().generate_random_bytes(8).hex_encode()}
 data.merge(fields);client.send_request(data)

func receive(ok: bool,message: String,_username: String):
 var was_purchase=purchase_pending;purchase_pending=false
 var data=client.tasks_snapshot if is_instance_valid(client) else {}
 if is_instance_valid(client):client.queue_free();client=null
 var valid=data is Dictionary and typeof(data.get("coins")) in [TYPE_INT,TYPE_FLOAT] and data.get("daily") is Dictionary and data.get("season") is Dictionary and data.daily.get("tasks") is Array
 if valid:
  snapshot=data.duplicate(true)
  # Server time and a monotonic deadline survive a wrong or adjusted device clock.
  var remaining=maxi(0,int(data.daily.get("resets_at",0))-int(data.get("server_time",0)))
  rollover_at_ms=Time.get_ticks_msec()+remaining*1000 if data.has("server_time") and data.daily.has("resets_at") else 0
  rollover_retry_ms=0
 if not ok or not valid:
  error="任务服务尚未更新" if message=="账号须为 3–24 位英文字母、数字或下划线" or (ok and data.get("daily") is Dictionary and not data.daily.has("tasks")) else message if not ok else "任务服务器响应无效"
 changed.emit()
 if was_purchase:purchase_finished.emit(ok and valid,message)
 if refresh_pending:refresh_pending=false;call_deferred("refresh")

func _process(_delta):
 if daily_expired() and Time.get_ticks_msec()>=rollover_retry_ms:
  rollover_retry_ms=Time.get_ticks_msec()+15000
  changed.emit();refresh()

func cancel_request():
 purchase_pending=false
 if is_instance_valid(client):
  if client.peer!=null:client.peer.close();client.peer=null
  client.set_process(false);client.queue_free();client=null

func _exit_tree():cancel_request()
