extends Node
const Transport=preload("res://net/lan_transport.gd")
const ObserverView=preload("res://net/observer_projection.gd")
var session
var transport
var watchers={}
var pending_events=[]
var cached={}
var dirty=true
var tick=0
var listening=false
func start(owner_session):
 session=owner_session
 transport=Transport.new();transport.throttled=true;add_child(transport)
 transport.received.connect(receive)
 transport.disconnected.connect(func(id):watchers.erase(id))
 transport.failed.connect(func(_message):pass)
 listening=session.port<65535 and transport.host_room(session.port+1,session.bind_address,4)==OK
func close():
 if transport:transport.close()
 watchers.clear();cached={};pending_events.clear();listening=false
func changed(events: Array=[]):
 dirty=true
 if not watchers.is_empty():pending_events.append_array(events.duplicate(true))
 if pending_events.size()>128:pending_events.clear()
func receive(id: int,message: Dictionary):
 var type=message.get("type","")
 if type=="watch":
  if message.get("version")!=session.fingerprint or session.room_id.is_empty():transport.drop(id);return
  if not watchers.has(id):watchers[id]={"seen":Time.get_ticks_msec(),"sent":-1,"ack":-1}
  dirty=true;return
 if not watchers.has(id):return
 watchers[id].seen=Time.get_ticks_msec()
 if type=="watch_ack" and int(message.get("sequence",-2))==watchers[id].sent:watchers[id].ack=watchers[id].sent
 elif type=="ping":transport.send_to(id,session.metrics.make_pong(message,Time.get_ticks_msec()),true)
 elif type=="leave":watchers.erase(id);transport.drop(id)
 # There is deliberately no command or room-action dispatch on this transport.
func _process(_delta):
 if not listening or session==null:return
 var now=Time.get_ticks_msec()
 if now-tick<200:return
 tick=now
 for id in watchers.keys():
  if now-watchers[id].seen>12000:watchers.erase(id);transport.drop(id)
 if watchers.is_empty():return
 if dirty:
  var room=session.series.public_state(-1)
  cached={"type":"watch_state","room_id":session.room_id,"sequence":session.sequence,"game_id":room.game_id,"room":room,"paused":session.paused,"recovery":false}
  cached.rewinds=session.rewind_events.duplicate(true)
  if not cached.rewinds.is_empty() and cached.rewinds.back().id==cached.sequence:cached.recovery=true
  if session.authority!=null:cached.projection=ObserverView.build(session.authority,pending_events)
  pending_events.clear();dirty=false
 for id in watchers:
  var watcher=watchers[id]
  if watcher.sent!=watcher.ack:continue
  # Include the pause/result status even when no rules command was issued.
  var tag=str(cached.sequence)+str(cached.room.status)+str(cached.paused)+str(cached.room.get("undo_request",{}))
  if watcher.get("tag","")==tag:continue
  watcher.sent=cached.sequence;watcher.tag=tag
  transport.send_to(id,cached)
