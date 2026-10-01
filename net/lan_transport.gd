extends Node
signal connected(peer_id: int)
signal disconnected(peer_id: int)
signal received(peer_id: int,message: Dictionary)
signal failed(message: String)
signal relay_ready
signal relay_seats_changed(seats: Array,peer_ids: Array)
signal relay_seat_changed(seat: int,role: String)
signal relay_notice(message: String)
const MAX_BYTES=16*1024*1024
const CHUNK=12000
var peer: MultiplayerPeer
var chunks={}
var packet_serial=0
var peers=[]
var online=false
var throttled=false
var outbound=[]
var next_send=0
var relay_role=""
var relay_code=""
var relay_websocket=false
var relay_token=""
var relay_options={}
var relay_seat=0
var relay_peer_roles={}
var relay_peer_seats={}

func relay_host(address: String,port: int,code: String,websocket: bool=false,token: String="",options: Dictionary={}) -> Error:
 return connect_relay(address,port,code,"host",websocket,token,options)

func relay_join(address: String,port: int,code: String,websocket: bool=false,token: String="",options: Dictionary={},watch: bool=false) -> Error:
 return connect_relay(address,port,code,"watch" if watch else "guest",websocket,token,options)

func connect_relay(address: String,port: int,code: String,role: String,websocket: bool,token: String="",options: Dictionary={}) -> Error:
 close();relay_role=role;relay_code=code;relay_websocket=websocket;relay_token=token;relay_options=options.duplicate(true)
 var err: Error
 if websocket:
  var websocket_peer=WebSocketMultiplayerPeer.new()
  err=websocket_peer.create_client("ws://"+address+":"+str(port))
  peer=websocket_peer
 else:
  var enet_peer=ENetMultiplayerPeer.new()
  err=enet_peer.create_client(address,port,2)
  peer=enet_peer
 if err!=OK:peer=null;relay_role="";return err
 bind_signals();online=true;return OK

func relay_control(kind: String):
 if peer==null or peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return
 peer.set_target_peer(1);peer.transfer_channel=0;peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
 var payload={"kind":kind,"room":relay_code,"token":relay_token}
 payload.merge(relay_options,true)
 peer.put_packet(("MCR1"+JSON.stringify(payload)).to_utf8_buffer())
func relay_update(status: String,name: String,ready: Array=[false,false],round_number: int=0):
 if relay_role!="host" or peer==null or peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return
 peer.set_target_peer(1);peer.transfer_channel=0;peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
 peer.put_packet(("MCR1"+JSON.stringify({"kind":"update","status":status,"name":name,"ready":ready,"round":round_number})).to_utf8_buffer())
func relay_move(from_slot: int,to_slot: int):
 if relay_role!="host" or peer==null or peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return
 peer.set_target_peer(1);peer.transfer_channel=0;peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
 peer.put_packet(("MCR1"+JSON.stringify({"kind":"move","from":from_slot,"to":to_slot})).to_utf8_buffer())
func host_room(port: int,bind_address: String="*",max_clients: int=1) -> Error:
 close()
 var enet_peer=ENetMultiplayerPeer.new();enet_peer.set_bind_ip(bind_address)
 var err=enet_peer.create_server(port,max_clients,2)
 if err!=OK:peer=null;return err
 peer=enet_peer
 bind_signals();online=true;return OK
func join_room(address: String,port: int) -> Error:
 close()
 var enet_peer=ENetMultiplayerPeer.new()
 var err=enet_peer.create_client(address,port,2)
 if err!=OK:peer=null;return err
 peer=enet_peer
 bind_signals();online=true;return OK
func bind_signals():
 peer.peer_connected.connect(func(id):
  if relay_role.is_empty():peers.append(id);connected.emit(id)
  else:relay_control(relay_role))
 peer.peer_disconnected.connect(func(id):
  if relay_role.is_empty():peers.erase(id);disconnected.emit(id))
func close():
 if peer:peer.close()
 peer=null;online=false;chunks.clear();peers.clear();outbound.clear();relay_role="";relay_code="";relay_websocket=false;relay_token="";relay_options={};relay_seat=0;relay_peer_roles.clear();relay_peer_seats.clear()
func drop(id: int):
 outbound=outbound.filter(func(packet):return packet.peer!=id)
 if relay_role=="host":
  if peer!=null:
   peer.set_target_peer(1);peer.transfer_channel=0;peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
   peer.put_packet(("MCR1"+JSON.stringify({"kind":"drop","peer":id})).to_utf8_buffer())
  peers.erase(id)
 elif peer:peer.disconnect_peer(id)
func send_to(id: int,message: Dictionary,heartbeat: bool=false):
 if peer==null or peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return
 var data=var_to_bytes(message)
 if data.size()>MAX_BYTES:failed.emit("同步数据超过限制");return
 # Large state snapshots are sent after every action. The receiver already
 # accepts this wrapper, so compress them before reliable-channel chunking.
 if data.size()>CHUNK:
  var packed=var_to_bytes({"compressed":data.compress(FileAccess.COMPRESSION_ZSTD),"raw_size":data.size()})
  if packed.size()<data.size():data=packed
 packet_serial+=1
 var hash_value=data.hex_encode().sha256_text()
 var channel=1 if heartbeat else 0
 for i in range(ceili(float(data.size())/CHUNK)):
  var frame={"id":packet_serial,"index":i,"count":ceili(float(data.size())/CHUNK),"hash":hash_value,"data":data.slice(i*CHUNK,mini((i+1)*CHUNK,data.size()))}
  if throttled:
   if outbound.size()<2048:outbound.append({"peer":id,"channel":channel,"bytes":var_to_bytes(frame)})
  else:send_frame(id,channel,var_to_bytes(frame))
func send_frame(id: int,channel: int,bytes: PackedByteArray):
 if peer==null or id not in peers:return
 peer.set_target_peer(id);peer.transfer_channel=0 if relay_websocket else channel;peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
 var outgoing=bytes
 if relay_role=="host":outgoing=("MCD1"+"%08X" % id).to_utf8_buffer()+bytes
 var err=peer.put_packet(outgoing)
 if err!=OK and not throttled:failed.emit("发送失败："+error_string(err))
func _process(_delta):
 if peer==null:return
 peer.poll()
 if throttled and Time.get_ticks_msec()>=next_send:
  next_send=Time.get_ticks_msec()+200
  for _i in range(mini(4,outbound.size())):
   var packet=outbound.pop_front();send_frame(packet.peer,packet.channel,packet.bytes)
 if peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED:
  close();failed.emit("连接已断开");return
 var budget=0
 while peer!=null and peer.get_available_packet_count()>0 and budget<(32 if throttled else 512):
  budget+=1
  var id=peer.get_packet_peer();var bytes=peer.get_packet()
  if not relay_role.is_empty() and bytes.size()<=2048 and bytes.get_string_from_utf8().begins_with("MCR1"):
   var control=JSON.parse_string(bytes.get_string_from_utf8().substr(4))
   if control is Dictionary:
    match control.get("kind",""):
     "registered":relay_seat=int(control.get("seat",0));relay_ready.emit()
     "joined":
      var joined_id=int(control.get("peer",0))
      relay_peer_seats[joined_id]=int(control.get("seat",0))
      if joined_id>1 and joined_id not in peers:
       relay_peer_roles[joined_id]=str(control.get("role","guest"));peers.append(joined_id);connected.emit(joined_id)
     "paired":
      relay_seat=int(control.get("seat",0))
      relay_seat_changed.emit(relay_seat,str(control.get("role","guest")))
      if 1 not in peers:peers.append(1);connected.emit(1)
     "seat_state":
      if control.get("seats") is Array and control.get("peers") is Array:
       for index in range(control.peers.size()):
        var peer_id=int(control.peers[index])
        if peer_id>1:
         relay_peer_seats[peer_id]=index+1
         relay_peer_roles[peer_id]="guest" if index<2 else "watch"
       relay_seats_changed.emit(control.seats,control.peers)
     "seat_changed":
      relay_seat=int(control.get("seat",0))
      relay_seat_changed.emit(relay_seat,str(control.get("role","guest")))
     "guest_left":
      var gone=int(control.get("peer",1))
      if gone in peers:peers.erase(gone);disconnected.emit(gone)
      relay_peer_roles.erase(gone)
      relay_peer_seats.erase(gone)
     "error":failed.emit(str(control.get("message","中转服务拒绝连接")))
     "move_error":relay_notice.emit(str(control.get("message","无法调整座位")))
   continue
  if relay_role=="host" and bytes.size()>12 and bytes.slice(0,4).get_string_from_ascii()=="MCD1":
   id=bytes.slice(4,12).get_string_from_ascii().hex_to_int();bytes=bytes.slice(12)
  if not relay_role.is_empty() and id not in peers:continue
  if bytes.size()<4 or bytes.size()>CHUNK+1024 or bytes[0]!=TYPE_DICTIONARY:continue
  var f=bytes_to_var(bytes)
  if not f is Dictionary or not f.get("data") is PackedByteArray:continue
  if not f.get("count") is int or not f.get("index") is int or not f.get("id") is int:continue
  if f.count<1 or f.count>ceili(float(MAX_BYTES)/CHUNK) or f.index<0 or f.index>=f.count:continue
  var key=str(id)+":"+str(f.id)
  if not chunks.has(key):
   if chunks.size()>8:continue
   chunks[key]={"parts":{},"count":f.count,"hash":f.get("hash","") ,"at":Time.get_ticks_msec()}
  var assembly=chunks[key]
  if f.count!=assembly.count or f.get("hash","")!=assembly.hash:chunks.erase(key);continue
  assembly.parts[f.index]=f.data
  if assembly.parts.size()==assembly.count:
   var joined=PackedByteArray()
   for i in range(assembly.count):joined.append_array(assembly.parts[i])
   chunks.erase(key)
   if joined.size()<4 or joined[0]!=TYPE_DICTIONARY or joined.size()>MAX_BYTES or joined.hex_encode().sha256_text()!=assembly.hash:continue
   var message=bytes_to_var(joined)
   if message is Dictionary and message.get("compressed") is PackedByteArray:
    if not message.get("raw_size") is int or message.raw_size<4 or message.raw_size>MAX_BYTES:continue
    var expanded=message.compressed.decompress(message.raw_size,FileAccess.COMPRESSION_ZSTD)
    if expanded.size()!=message.raw_size or expanded[0]!=TYPE_DICTIONARY:continue
    message=bytes_to_var(expanded)
   if message is Dictionary:received.emit(id,message)
 for key in chunks.keys():
  if Time.get_ticks_msec()-chunks[key].at>15000:chunks.erase(key)
func _exit_tree():close()
