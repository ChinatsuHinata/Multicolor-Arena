extends SceneTree
const Session=preload("res://net/lan_session.gd")
const SpectatorHub=preload("res://net/spectator_hub.gd")

class CapturedTransport:
 extends Node
 var relay_peer_roles={}
 var sent=[]
 func send_to(id: int,message: Dictionary,_heartbeat: bool=false):
  sent.append({"id":id,"message":message.duplicate(true)})

var checks=0
var failures=[]
func _initialize():call_deferred("run")
func expect(ok: bool,title: String):
 checks+=1
 if ok:print("PASS: "+title)
 else:failures.append(title);push_error(title)
func make_session(cloud: bool,host: bool,observer: bool=false):
 var session=Session.new()
 session.is_host=host;session.cloud_mode=cloud;session.read_only=observer
 session.cloud_slot=1 if host else 3 if observer else 2
 session.cloud_peer_ids=[1,2,3,0,0,0,0,0]
 session.cloud_player_records[1]={"token":"guest"};session.guest={"token":"guest"}
 session.remote_peer=2 if host else 1
 session.room_id="room";session.room={"status":"lobby","names":["房主","玩家"]}
 session.connected=true;session.paused=false;session.remote_last_seen=123
 session.transport=CapturedTransport.new();session.add_child(session.transport)
 if cloud and host:
  session.transport.relay_peer_roles={2:"guest",3:"watch"}
  session.spectator_hub=SpectatorHub.new();session.add_child(session.spectator_hub)
  session.spectator_hub.session=session;session.spectator_hub.transport=session.transport
  session.spectator_hub.watchers[3]={"seen":123,"sent":0,"ack":0}
 return session
func run():
 for cloud in [false,true]:
  for host in [true,false]:
   var session=make_session(cloud,host)
   var label=("cloud" if cloud else "LAN")+(" host" if host else " guest")
   expect(not session.has_method("send_chat") and not session.has_signal("chat_received"),label+" has no chat API")
   var before=session.room.duplicate(true)
   session.receive(2 if host else 1,{"type":"chat","room_id":"room","seat":0,"text":"旧聊天消息"})
   expect(session.transport.sent.is_empty() and session.room==before and session.remote_last_seen==123,label+" ignores legacy chat without refreshing connection")
   session.receive(2 if host else 1,{"type":"ping","at":123})
   expect(session.transport.sent.size()==1 and session.transport.sent[0].message.type=="pong",label+" still responds to heartbeats")
   if cloud and host:
    session.transport.sent.clear()
    session.receive(3,{"type":"chat","room_id":"room","text":"旧观战聊天"})
    expect(session.transport.sent.is_empty() and session.spectator_hub.watchers[3].seen==123,"cloud spectator chat is ignored by the host")
    session.receive(3,{"type":"watch_ack","sequence":0})
    expect(session.spectator_hub.watchers[3].seen!=123,"cloud spectator synchronization remains active")
   session.free()
  var observer=make_session(cloud,false,true)
  observer.receive(1,{"type":"chat","room_id":"room","seat":0,"text":"旧聊天广播"})
  expect(observer.transport.sent.is_empty() and observer.remote_last_seen==123 and observer.snapshots.is_empty(),("cloud" if cloud else "LAN")+" spectator ignores legacy chat broadcasts")
  observer.free()
 expect(not FileAccess.file_exists("res://net/chat_panel.gd"),"chat panel source is removed")
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://net/rules_manifest.json"))
 expect(not manifest.files.has("net/chat_panel.gd"),"network manifest no longer references chat panel")
 print("NETWORK CHAT REMOVED: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
