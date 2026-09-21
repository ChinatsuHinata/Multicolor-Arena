extends RefCounted
const Paths=preload("res://scripts/portable_paths.gd")
const MAGIC="MREPLY1\n"
const MAX_FILE=128*1024*1024
const MAX_FRAME=16*1024*1024
var metadata={}
var frames: Array=[]
var definitions={}
var last_key=""
var bytes_used=0
var raw_bytes_used=0
var failure=""
var finished=false
var prompted=false
var capture_path=""
var capture_warning=""
static func digest_bytes(data: PackedByteArray) -> PackedByteArray:
 var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(data);return context.finish()
func record(packet: Dictionary,perspective: int=0):
 if metadata.is_empty():metadata={"format":"multicolor:arena/replay","version":1,"created":Time.get_datetime_string_from_system(),"seat":perspective,"rules":FileAccess.get_file_as_string("res://net/rules_manifest.json").sha256_text(),"room":{},"perspective":"public" if perspective<0 else "player"}
 apply_rewinds(packet.get("rewinds",[]))
 var key=str(packet.game_id)+":"+str(packet.sequence)+":"+str(packet.room.get("status",""))
 var rewinds=packet.get("rewinds",[])
 if not rewinds.is_empty() and int(rewinds.back().id)==int(packet.sequence) and not frames.is_empty():
  var previous=frame(frames.size()-1)
  if previous.game_id==rewinds.back().game and int(previous.sequence)==int(rewinds.back().sequence):last_key=key;return
 if key==last_key or finished or not failure.is_empty():return
 last_key=key
 var copy=packet.duplicate(true)
 copy.erase("rewinds");copy.room.erase("undo_request");copy.room.erase("undo_available")
 metadata.room=copy.room.duplicate(true);metadata.room.erase("own_deck")
 copy.room.erase("own_deck");copy.erase("ack_id")
 var new_definitions={}
 for id in copy.projection.definitions:
  if not definitions.has(id) or definitions[id]!=copy.projection.definitions[id]:new_definitions[id]=copy.projection.definitions[id]
 definitions.merge(new_definitions,true);copy.projection.erase("definitions")
 # Record only the data used for drawing; do not store commands or private target pools.
 var q={}
 for k in ["stats","leader","sick","haste"]:q[k]=copy.projection.queries.get(k,{})
 copy.projection.queries=q;copy.projection.state.pending={};copy.projection.state.forced_cast={}
 var raw=var_to_bytes(copy)
 if raw.size()>MAX_FRAME:failure="单步回放数据过大";return
 raw_bytes_used+=raw.size()
 if raw_bytes_used>512*1024*1024:failure="回放展开数据超过限制";return
 var compressed=raw.compress(FileAccess.COMPRESSION_ZSTD)
 bytes_used+=compressed.size()
 if bytes_used>MAX_FILE-1024*1024 or frames.size()>=50000:failure="回放超过容量限制";return
 frames.append({"bytes":compressed,"size":raw.size(),"time":Time.get_ticks_msec(),"game":str(packet.game_id),"round":int(packet.room.get("round",1)),"turn":int(packet.projection.state.turn)})
 append_capture({"frame":frames.back(),"definitions":new_definitions,"metadata":metadata,"key":key})
func begin_capture(path: String,match_id: String=""):
 capture_path=path
 if not match_id.is_empty() and FileAccess.file_exists(path):
  var f=FileAccess.open(path,FileAccess.READ)
  if f!=null and f.get_length()<=MAX_FILE and f.get_buffer(6).get_string_from_utf8()=="MCAP1\n":
   var recovered=[];var info={};var known={};var key=""
   while f.get_position()+36<=f.get_length():
    var length=f.get_32();var digest=f.get_buffer(32)
    if length>MAX_FRAME or f.get_position()+length>f.get_length():break
    var raw=f.get_buffer(length)
    if digest_bytes(raw)!=digest:break
    var data=bytes_to_var(raw)
    if not data is Dictionary or not data.get("frame") is Dictionary:break
    recovered.append(data.frame);known.merge(data.get("definitions",{}),true);info=data.get("metadata",{});key=data.get("key","")
   if info.get("room",{}).get("match_id","")==match_id:
    frames=recovered;definitions=known;metadata=info;last_key=key
    for entry in frames:bytes_used+=entry.bytes.size();raw_bytes_used+=entry.size
 # Rewrite a recovered prefix once; a truncated tail cannot hide future appended records.
 var out=FileAccess.open(path,FileAccess.WRITE)
 if out==null:capture_warning="无法保存回放恢复记录";capture_path="";return
 out.store_string("MCAP1\n");out.close()
 for i in range(frames.size()):append_capture({"frame":frames[i],"definitions":definitions if i==0 else {},"metadata":metadata,"key":last_key if i==frames.size()-1 else ""})
func append_capture(data: Dictionary):
 if capture_path.is_empty():return
 var f=FileAccess.open(capture_path,FileAccess.READ_WRITE)
 if f==null:capture_warning="无法写入回放恢复记录";return
 var raw=var_to_bytes(data)
 if f.get_length()+raw.size()+36>MAX_FILE:capture_warning="回放恢复记录超过容量限制";return
 f.seek_end();f.store_32(raw.size());f.store_buffer(digest_bytes(raw));f.store_buffer(raw);f.flush()
 if f.get_error()!=OK:capture_warning="回放恢复记录写入未完成"
 f.close()
func apply_rewinds(events: Array):
 var changed=false
 for event in events:
  if int(event.get("id",0))<=int(metadata.get("_rewind_seen",0)):continue
  metadata._rewind_seen=event.id
  while not frames.is_empty():
   var last=frame(frames.size()-1)
   if last.game_id!=event.game or int(last.sequence)<=int(event.sequence):break
   frames.pop_back();changed=true
 if not changed:return
 bytes_used=0;raw_bytes_used=0;last_key=""
 for entry in frames:bytes_used+=entry.bytes.size();raw_bytes_used+=entry.size
 # Replace the capture prefix so a later reconnect cannot resurrect an abandoned branch.
 if not capture_path.is_empty():
  var out=FileAccess.open(capture_path,FileAccess.WRITE)
  if out!=null:
   out.store_string("MCAP1\n");out.close()
   for i in range(frames.size()):append_capture({"frame":frames[i],"definitions":definitions if i==0 else {},"metadata":metadata,"key":""})
func finish(room: Dictionary):
 if frames.is_empty():return
 metadata.room=room.duplicate(true);metadata.room.erase("own_deck");finished=true
 metadata.room.erase("undo_request");metadata.room.erase("undo_available")
func frame(index: int) -> Dictionary:
 if index<0 or index>=frames.size():return {}
 var entry=frames[index]
 var data=entry.bytes.decompress(int(entry.size),FileAccess.COMPRESSION_ZSTD)
 if data.size()!=int(entry.size) or data.size()<4 or data[0]!=TYPE_DICTIONARY:return {}
 var packet=bytes_to_var(data)
 if not packet is Dictionary or not packet.get("projection") is Dictionary:return {}
 packet.projection.definitions=definitions
 return packet
func save(path: String="") -> Dictionary:
 if not failure.is_empty():return {"error":failure}
 if frames.is_empty():return {"error":"没有可保存的对局记录"}
 var error=Paths.initialize()
 if not error.is_empty():return {"error":error}
 if path.is_empty():
  var names=" vs ".join(metadata.room.get("names",["对局"]))
  var title=(metadata.created.replace(":","-")+" "+names).validate_filename().left(120)
  path=Paths.root().path_join("replay").path_join(title+"_"+str(Time.get_ticks_usec())+".mreply")
 var shared_metadata=metadata.duplicate(true);shared_metadata.erase("_rewind_seen")
 var payload=var_to_bytes({"metadata":shared_metadata,"definitions":definitions,"frames":frames})
 if payload.size()+40>MAX_FILE:return {"error":"回放文件过大"}
 var f=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if f==null:return {"error":"无法写入 replay 文件夹"}
 f.store_buffer(MAGIC.to_utf8_buffer());f.store_buffer(digest_bytes(payload));f.store_buffer(payload)
 f.flush();var status=f.get_error();f.close()
 if status!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK:return {"error":"回放保存失败，写入未完成"}
 return {"path":path}
static func read(path: String) -> Dictionary:
 var f=FileAccess.open(path,FileAccess.READ)
 if f==null or f.get_length()>MAX_FILE or f.get_length()<44:return {"error":"回放文件无效或过大"}
 if f.get_buffer(8).get_string_from_utf8()!=MAGIC:return {"error":"不支持的回放格式"}
 var digest=f.get_buffer(32);var raw=f.get_buffer(f.get_length()-40)
 if digest_bytes(raw)!=digest or raw.size()<4 or raw[0]!=TYPE_DICTIONARY:return {"error":"回放文件损坏，校验失败"}
 var data=bytes_to_var(raw)
 if not data is Dictionary or not data.get("metadata") is Dictionary or not data.get("definitions") is Dictionary or not data.get("frames") is Array:return {"error":"回放结构无效"}
 if data.metadata.get("format")!="multicolor:arena/replay" or data.metadata.get("version")!=1:return {"error":"不支持的回放版本"}
 if int(data.metadata.get("seat",-9)) not in [-1,0,1]:return {"error":"回放视角无效"}
 if data.metadata.get("rules")!=FileAccess.get_file_as_string("res://net/rules_manifest.json").sha256_text():return {"error":"请使用录制这场回放时的游戏版本播放"}
 if data.frames.is_empty() or data.frames.size()>50000:return {"error":"回放步数无效"}
 var raw_total=0
 for entry in data.frames:
  if not entry is Dictionary or not entry.get("bytes") is PackedByteArray or not entry.get("size") is int or entry.size<4 or entry.size>MAX_FRAME or not entry.get("game") is String or not entry.get("round") is int or not entry.get("time") is int:return {"error":"回放片段无效"}
  raw_total+=entry.size
  if raw_total>512*1024*1024:return {"error":"回放展开数据超过限制"}
 var archive=load("res://scripts/replay_archive.gd").new()
 archive.metadata=data.metadata;archive.frames=data.frames;archive.definitions=data.definitions;archive.finished=true
 for i in range(archive.frames.size()):
  var packet=archive.frame(i)
  if not valid_frame(packet,data.definitions):return {"error":"回放状态无效"}
 return {"archive":archive}
static func valid_frame(packet: Dictionary,known: Dictionary) -> bool:
 if packet.is_empty() or not packet.get("room") is Dictionary or not packet.projection.get("state") is Dictionary or not packet.projection.get("queries") is Dictionary:return false
 var state=packet.projection.state;var room=packet.room
 if not room.get("names") is Array or room.names.size()!=2 or not room.get("scores") is Array or room.scores.size()!=2 or not room.get("format") is int:return false
 if not state.get("players") is Array or state.players.size()!=2:return false
 if state.get("phase") not in ["mulligan","reset","prepare","draw","possession","main","end","over"]:return false
 for field in ["active","priority","first"]:
  if state.get(field) not in [0,1]:return false
 for field in ["turn","revision","winner"]:
  if not state.get(field) is int:return false
 if state.winner not in [-2,-1,0,1]:return false
 for field in ["stack","history","log","player_names"]:
  if not state.get(field) is Array:return false
 if state.player_names.size()!=2 or not state.player_names.all(func(n):return n is String):return false
 if room.get("winner",-2) not in [-2,-1,0,1] or not room.names.all(func(n):return n is String):return false
 for entry in state.stack:
  if not entry is Dictionary or entry.get("kind") not in ["ability","card"] or not entry.get("id") is int or not entry.get("name") is String:return false
  var c=entry.get("card" if entry.kind=="card" else "source",{})
  if not c is Dictionary or not known.has(c.get("card_id","")):return false
 for entry in state.history:
  if not entry is Dictionary or not entry.get("art") is Array or not entry.get("text") is String or not entry.has("turn"):return false
 if not state.get("combat") is Dictionary or not state.get("turn_usage") is Dictionary:return false
 for p in state.players:
  if not p is Dictionary or not p.get("leader") is Dictionary or not p.has("life"):return false
  for zone in ["deck","hand","field","palette","grave","exile"]:
   if not p.get(zone) is Array or p[zone].size()>4000:return false
   if not p.get("extra_leaders",[]) is Array or p.get("extra_leaders",[]).size()>8:return false
   for c in p[zone]+[p.leader]+p.get("extra_leaders",[]):
    if not c is Dictionary:return false
    if c.is_empty():continue
    if not c.get("uid") is int or not c.get("card_id") is String or c.get("zone") not in ["deck","hand","field","palette","grave","exile","leader","stack","return_pending"]:return false
    if c.card_id!="back" and not known.has(c.card_id):return false
 return true
