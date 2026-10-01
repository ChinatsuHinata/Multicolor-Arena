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

func start(server_url: String,login_token: String):
 stop()
 if login_token.is_empty():failed.emit("请先登录玩家账号");return
 url=server_url;token=login_token
 peer=WebSocketMultiplayerPeer.new()
 var err=peer.create_client(url)
 if err!=OK:peer=null;failed.emit("无法连接云端服务器："+error_string(err));return
 set_process(true)

func stop():
 if peer!=null:peer.close()
 peer=null;rooms=[];pending_rooms=[];expected_page=0;connected_once=false;set_process(false)

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
 if peer==null:return
 peer.poll()
 if peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED:
  stop();failed.emit("云端房间列表连接已断开");return
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
   "error":failed.emit(str(answer.get("message","云端请求失败")))

func _exit_tree():stop()
