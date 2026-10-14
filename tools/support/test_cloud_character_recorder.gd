extends "res://relay/server.gd"
const Recorder=preload("res://relay/match_character_log.gd")
var failures=0
var checks=0
var log_path="res://work/cloud-character-report/recorder-test.jsonl"
var forwarded=[]
func _initialize():call_deferred("run")
func _process(_delta) -> bool:return false
func send_raw(id: int,data: PackedByteArray,channel: int=0):
 forwarded.append({"id":id,"data":data,"channel":channel})
func verify(value: bool,message: String):
 checks+=1
 if not value:failures+=1;push_error(message)
func room(id: String="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") -> Dictionary:
 return {"ranked":true,"slots":[1,2],"match_id":id,"cancel":false}
func frames(data: PackedByteArray,serial: int=1) -> Array:
 var result=[]
 for index in range(ceili(float(data.size())/12000.0)):
  result.append(var_to_bytes({"id":serial,"count":ceili(float(data.size())/12000.0),"index":index,
   "hash":data.hex_encode().sha256_text(),"data":data.slice(index*12000,mini((index+1)*12000,data.size()))}))
 return result
func run():
 var absolute=ProjectSettings.globalize_path(log_path)
 verify(absolute.begins_with(ProjectSettings.globalize_path("res://work/cloud-character-report/")),"Test log must stay in its workspace directory")
 if FileAccess.file_exists(absolute):DirAccess.remove_absolute(absolute)
 var recorder=Recorder.new();recorder.log_path=log_path
 var packet={"type":"room","room":{"status":"playing","leaders":["68","70"]}}
 var wire=frames(var_to_bytes(packet))[0]
 var normal=room()
 verify(not recorder.observe(normal,3,wire),"Spectator packets must not produce separate records")
 var ordinary=room();ordinary.ranked=false
 verify(not recorder.observe(ordinary,2,wire),"Ordinary cloud rooms must not count as ranked matches")
 var cancelled=room();cancelled.cancel=true
 verify(not recorder.observe(cancelled,2,wire),"Cancelled matches must not produce a record")
 verify(recorder.observe(normal,2,wire),"Public leaders should be recorded")
 verify(not recorder.observe(normal,2,wire),"Repeated packets must not duplicate a match")
 var lines=FileAccess.get_file_as_string(absolute).strip_edges().split("\n")
 verify(lines.size()==1,"Exactly one record is expected")
 var entry=JSON.parse_string(lines[0])
 verify(entry.leaders==["68","70"] and entry.match_id==normal.match_id,"Seat order must be preserved")
 verify(not entry.has("token") and not entry.has("projection"),"The log must contain no account token or battle state")
 var malformed=room("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
 var bad=bytes_to_var(wire);bad.hash="0".repeat(64)
 verify(not recorder.observe(malformed,2,var_to_bytes(bad)),"A corrupted frame hash must be rejected")
 var lobby=room("cccccccccccccccccccccccccccccccc")
 var before=packet.duplicate(true);before.room.status="sideboarding"
 verify(not recorder.observe(lobby,2,frames(var_to_bytes(before),2)[0]),"Pre-game selection alone must not count as a played match")
 var large=packet.duplicate(true);large.padding="x".repeat(25000)
 var fragmented=frames(var_to_bytes(large),3);fragmented.reverse()
 var reordered=room("dddddddddddddddddddddddddddddddd")
 var emitted=0
 for part in fragmented:
  if recorder.observe(reordered,2,part):emitted+=1
 verify(emitted==1,"Out-of-order protocol chunks must assemble into one record")
 var raw=var_to_bytes(large)
 var compressed=var_to_bytes({"compressed":raw.compress(FileAccess.COMPRESSION_ZSTD),"raw_size":raw.size()})
 var compressed_room=room("eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
 verify(recorder.observe(compressed_room,2,frames(compressed,4)[0]),"Compressed snapshots must preserve leader metadata")
 var excessive=var_to_bytes({"compressed":raw.compress(FileAccess.COMPRESSION_ZSTD),"raw_size":17*1024*1024})
 verify(not recorder.observe(room("ffffffffffffffffffffffffffffffff"),2,frames(excessive,5)[0]),"Excessive decompression sizes must be rejected")
 character_log.log_path=log_path
 var integrated=room("11111111111111111111111111111111")
 clients={1:{"role":"host","room":"TEST"},2:{"role":"guest","room":"TEST"}}
 rooms={"TEST":integrated}
 handle_packet(1,"MCD100000002".to_utf8_buffer()+wire,1)
 verify(integrated.get("_character_recorded",false),"The relay forwarding path must invoke character recording")
 verify(forwarded.size()==1 and forwarded[0].id==2 and forwarded[0].data==wire and forwarded[0].channel==1,"Recording must preserve the forwarded packet and channel")
 var bad_wire=var_to_bytes(bad)
 rooms.TEST=room("22222222222222222222222222222222")
 handle_packet(1,"MCD100000002".to_utf8_buffer()+bad_wire,0)
 verify(not rooms.TEST.get("_character_recorded",false) and forwarded.back().data==bad_wire,"Invalid statistics metadata must still be forwarded unchanged")
 print("CLOUD_CHARACTER_RECORDER: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
