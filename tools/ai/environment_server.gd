extends SceneTree
## Loopback JSON-lines server: keep authoritative simulation state in Godot.
const Env=preload("res://scripts/ai/game_environment.gd")
const Training=preload("res://scripts/ai/replay_training.gd")
const Archive=preload("res://scripts/replay_archive.gd")
var server=TCPServer.new()
var peers=[]
var states={}
var next_state=1
var secret=""

func _initialize():
 var port=0
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--port="):port=int(arg.substr(7))
  if arg.begins_with("--token="):secret=arg.substr(8)
 if port<1 or secret.is_empty() or server.listen(port,"127.0.0.1")!=OK:push_error("Cannot start local algorithm environment");quit(1)

func _process(_delta):
 while server.is_connection_available():peers.append({"peer":server.take_connection(),"buffer":""})
 for row in peers:
  row.peer.poll()
  var size=row.peer.get_available_bytes()
  if size>0:row.buffer+=row.peer.get_utf8_string(size)
  if row.buffer.length()>4*1024*1024:row.peer.disconnect_from_host();continue
  while "\n" in row.buffer:
   var end=row.buffer.find("\n");var line=row.buffer.substr(0,end);row.buffer=row.buffer.substr(end+1)
   var request=Training.normalize_json(JSON.parse_string(line));var result={"error":"Invalid request"}
   if request is Dictionary:
    if request.get("token","")!=secret:result={"error":"Invalid session token"}
    else:result=dispatch(request)
   row.peer.put_data((JSON.stringify(result)+"\n").to_utf8_buffer())
 peers=peers.filter(func(row):return row.peer.get_status()!=StreamPeerTCP.STATUS_NONE)
 return false

func add(env) -> Dictionary:
 var id=next_state;next_state+=1;states[id]=env
 return {"state":id,"terminal":env.is_terminal(),"current_player":env.current_player()}

func dispatch(request: Dictionary) -> Dictionary:
 var op=request.get("op","")
 if op=="describe":return {"schema":"multicolor.ai.environment.v1","feature_schema":Env.Value.Strategic.SCHEMA,"abstraction":"main decisions; intermediate choices and responses use frozen engine AI","chance":"sampled seeded RNG; no explicit chance nodes","action_ids":"48-bit stable action hashes; state-local legal mask","supports":["reset","load_replay","observation","features","legal_actions","policy_actions","step","clone","sample","returns","release"]}
 if op=="shutdown":call_deferred("quit");return {"ok":true}
 if op=="reset":
  var decks=[]
  for path in request.get("decks",[]):
   if not path.begins_with("res://deck/"):return {"error":"Deck path must be inside res://deck"}
   var doc=JSON.parse_string(FileAccess.get_file_as_string(path))
   if not doc is Dictionary or not doc.has("deck"):return {"error":"Invalid deck"}
   decks.append(doc.deck)
  var env=Env.new();var result=env.reset(decks,int(request.get("first",0)),int(request.get("seed",7)))
  if result.has("error"):return result
  return add(env)
 if op=="load_replay":
  var path=request.get("path","")
  if not path.begins_with("res://replay/"):return {"error":"Replay path must be inside res://replay"}
  var loaded=Archive.read(path)
  if loaded.has("error"):return loaded
  var index=int(request.get("frame",0))
  if index<0 or index>=loaded.archive.frames.size():return {"error":"Invalid frame"}
  var packet=loaded.archive.frame(index)
  if not packet.projection.get("training_context",{}).get("decision_point",false):return {"error":"Replay did not record a clean main decision"}
  var training=Training.new();training.archive=loaded.archive
  var env=Env.new();env.setup(training.restore(index),request.get("priors",[]))
  if not env.engine.players[env.current_player()].hand.all(func(c):return c.card_id!="back"):return {"error":"Acting hand unavailable"}
  return add(env)
 var env=states.get(int(request.get("state",-1)))
 if env==null:return {"error":"Unknown state"}
 var who=int(request.get("player",env.current_player()))
 if who not in [0,1]:who=0
 match op:
  "clone":return add(env.clone())
  "sample":
   var sampled=env.resample_from_infostate(who,int(request.get("seed",7)))
   return sampled if sampled.has("error") else add(sampled.environment)
  "observation":return {"observation":env.observation(who),"information_state":env.information_state_string(who)}
  "features":return {"features":env.features(who)}
  "legal_actions":return env.legal_actions()
  "policy_actions":return env.policy_actions()
  "step":return env.apply_action(int(request.get("action",-1)))
  "returns":return {"terminal":env.is_terminal(),"returns":env.returns()}
  "release":states.erase(int(request.state));return {"ok":true}
 return {"error":"Unknown operation"}
