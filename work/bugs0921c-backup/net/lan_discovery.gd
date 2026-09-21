extends Node
signal rooms_changed
const PRODUCT="multicolour-lan-v1"
const PORT=47860
var socket: PacketPeerUDP
var hosting=false
var metadata={}
var rooms={}
var clock_time=0.0
var error=""
func start(host: bool=false,info: Dictionary={},bind_address: String="*"):
 stop();hosting=host;metadata=info;socket=PacketPeerUDP.new()
 var result=socket.bind(PORT if host else 0,bind_address)
 if result!=OK:error="房间发现不可用，可使用地址加入（"+error_string(result)+"）";socket=null;return
 socket.set_broadcast_enabled(true);clock_time=1.0
func stop():
 if socket:socket.close()
 socket=null;rooms.clear()
func _process(delta):
 if socket==null:return
 clock_time+=delta
 if not hosting and clock_time>=1.0:
  clock_time=0
  for destination in ["255.255.255.255","127.0.0.1"]:
   socket.set_dest_address(destination,PORT);socket.put_packet(JSON.stringify({"product":PRODUCT,"query":true}).to_utf8_buffer())
 var budget=0
 while socket.get_available_packet_count()>0 and budget<64:
  budget+=1
  var bytes=socket.get_packet();var address=socket.get_packet_ip();var port=socket.get_packet_port()
  if bytes.size()>2048:continue
  var packet=JSON.parse_string(bytes.get_string_from_utf8())
  if not packet is Dictionary or packet.get("product","")!=PRODUCT:continue
  if hosting and packet.get("query",false):
   var reply=metadata.duplicate(true);reply.product=PRODUCT
   socket.set_dest_address(address,port);socket.put_packet(JSON.stringify(reply).to_utf8_buffer())
  elif not hosting and packet.get("room_id") is String and packet.get("name") is String and packet.get("port") is float:
   if packet.name.length()>40 or packet.room_id.length()>64 or packet.port<1024 or packet.port>65535:continue
   packet.address=address;packet.at=Time.get_ticks_msec();rooms[packet.room_id]=packet;rooms_changed.emit()
 for id in rooms.keys():
  if Time.get_ticks_msec()-rooms[id].at>5000:rooms.erase(id);rooms_changed.emit()
func _exit_tree():stop()
