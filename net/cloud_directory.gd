extends Node
signal changed
signal failed(message: String)

var peer: WebSocketMultiplayerPeer
var rooms: Array=[]
var url=""
var token=""
var last_request=0
var connected_once=false
var pending_rooms: Array=[]
var expected_page=0
var active=false
var retry_at=0
var is_android=OS.has_feature("android")
var application_suspended=false

func start(server_url: String,login_token: String):
 stop()
 if login_token.is_empty():failed.emit("请先登录玩家账号");return
 url=server_url;token=login_token
 active=true
 connect_peer()

func connect_peer():
 peer=WebSocketMultiplayerPeer.new()
 var err=peer.create_client(url)
 retry_at=Time.get_ticks_msec()+3000
 if err!=OK:
  stop();failed.emit("无法连接云端服务器："+error_string(err));return
 connected_once=false;pending_rooms=[];expected_page=0
 set_process(true)

func stop():
 if peer!=null:peer.close()
 peer=null;active=false;rooms=[];pending_rooms=[];expected_page=0;connected_once=false;set_process(false)

func _notification(what):
 if not is_android:return
 if what==NOTIFICATION_APPLICATION_PAUSED:application_suspended=true
 elif what==NOTIFICATION_APPLICATION_RESUMED:
  if not application_suspended:return
  application_suspended=false
  if not active:return
  retry_at=0;last_request=0
  if peer==null:connect_peer()
  else:refresh()

func refresh():
 if peer==null or peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return
 pending_rooms=[];expected_page=0
 request_page(0)
 last_request=Time.get_ticks_msec()

func request_page(page: int):
 if peer==null or peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return
 peer.set_target_peer(1);peer.transfer_channel=0;peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
 peer.put_packet(("MCR1"+JSON.stringify({"kind":"list","token":token,"page":page})).to_utf8_buffer())

func _process(_delta):
 if not active or application_suspended:return
 if peer==null:
  if Time.get_ticks_msec()>=retry_at:connect_peer()
  return
 peer.poll()
 if peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED:
  peer.close();peer=null;retry_at=Time.get_ticks_msec()+3000;return
 if peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return
 if not connected_once or Time.get_ticks_msec()-last_request>3000:
  connected_once=true;refresh()
 while peer!=null and peer.get_available_packet_count()>0:
  var data=peer.get_packet()
  if data.size()<4 or data.size()>262144 or data.slice(0,4).get_string_from_ascii()!="MCR1":continue
  var answer=JSON.parse_string(data.slice(4).get_string_from_utf8())
  if not answer is Dictionary:continue
  match str(answer.get("kind","")):
   "rooms":
    if answer.get("rooms") is Array and int(answer.get("page",-1))==expected_page:
     pending_rooms.append_array(answer.rooms)
     expected_page+=1
     if expected_page<int(answer.get("pages",1)):request_page(expected_page)
     else:rooms=pending_rooms.duplicate(true);changed.emit()
   "error":
    var message=str(answer.get("message","云端请求失败"))
    stop();failed.emit(message)

func _exit_tree():stop()
