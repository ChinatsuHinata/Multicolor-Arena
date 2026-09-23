extends Node
signal connected(peer_id: int)
signal disconnected(peer_id: int)
signal received(peer_id: int,message: Dictionary)
signal failed(message: String)
const MAX_BYTES=16*1024*1024
const CHUNK=12000
var peer: ENetMultiplayerPeer
var chunks={}
var packet_serial=0
var peers=[]
var online=false
var throttled=false
var outbound=[]
var next_send=0
func host_room(port: int,bind_address: String="*",max_clients: int=1) -> Error:
 close();peer=ENetMultiplayerPeer.new();peer.set_bind_ip(bind_address)
 var err=peer.create_server(port,max_clients,3)
 if err!=OK:peer=null;return err
 bind_signals();online=true;return OK
func join_room(address: String,port: int) -> Error:
 close();peer=ENetMultiplayerPeer.new()
 var err=peer.create_client(address,port,3)
 if err!=OK:peer=null;return err
 bind_signals();online=true;return OK
func bind_signals():
 peer.peer_connected.connect(func(id):peers.append(id);connected.emit(id))
 peer.peer_disconnected.connect(func(id):peers.erase(id);disconnected.emit(id))
func close():
 if peer:peer.close()
 peer=null;online=false;chunks.clear();peers.clear();outbound.clear()
func drop(id: int):
 outbound=outbound.filter(func(packet):return packet.peer!=id)
 if peer:peer.disconnect_peer(id)
func send_to(id: int,message: Dictionary,heartbeat: bool=false,channel_override: int=-1):
 if peer==null or peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return
 var data=var_to_bytes(message)
 if data.size()>MAX_BYTES:failed.emit("同步数据超过限制");return
 if throttled:
  data=var_to_bytes({"compressed":data.compress(FileAccess.COMPRESSION_ZSTD),"raw_size":data.size()})
 packet_serial+=1
 var hash_value=data.hex_encode().sha256_text()
 var channel=channel_override if channel_override>=0 else 1 if heartbeat else 0
 for i in range(ceili(float(data.size())/CHUNK)):
  var frame={"id":packet_serial,"index":i,"count":ceili(float(data.size())/CHUNK),"hash":hash_value,"data":data.slice(i*CHUNK,mini((i+1)*CHUNK,data.size()))}
  if throttled:
   if outbound.size()<2048:outbound.append({"peer":id,"channel":channel,"bytes":var_to_bytes(frame)})
  else:send_frame(id,channel,var_to_bytes(frame))
func send_frame(id: int,channel: int,bytes: PackedByteArray):
 if peer==null or id not in peers:return
 peer.set_target_peer(id);peer.transfer_channel=channel;peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
 var err=peer.put_packet(bytes)
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
