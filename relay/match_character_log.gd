extends RefCounted
## Observe the host's existing public room packets; retain only two leader IDs.
const CHUNK=12000
const MAX_PACKED=2*1024*1024
const MAX_RAW=16*1024*1024
var log_path="res://data/match_leaders.jsonl"

func observe(room: Dictionary,target: int,wire: PackedByteArray) -> bool:
 if not room.get("ranked",false) or room.get("_character_recorded",false) or room.get("cancel",false):return false
 var slots=room.get("slots",[])
 if slots.size()<2 or target!=slots[1] or str(room.get("match_id","")).length()!=32:return false
 if wire.size()<4 or wire.size()>CHUNK+1024 or wire[0]!=TYPE_DICTIONARY:return false
 var frame=bytes_to_var(wire)
 if not frame is Dictionary or not frame.get("data") is PackedByteArray:return false
 if not frame.get("id") is int or not frame.get("count") is int or not frame.get("index") is int:return false
 if frame.count<1 or frame.count>ceili(float(MAX_PACKED)/CHUNK) or frame.index<0 or frame.index>=frame.count:return false
 if not frame.get("hash") is String or frame.hash.length()!=64 or frame.data.size()>CHUNK:return false
 var parts=room.get("_character_parts",{})
 var now=Time.get_ticks_msec()
 for key in parts.keys():
  if now-int(parts[key].at)>15000:parts.erase(key)
 var key=str(frame.id)
 if not parts.has(key):
  if parts.size()>=8:return false
  parts[key]={"count":frame.count,"hash":frame.hash,"parts":{},"size":0,"at":now}
 room._character_parts=parts
 var assembly=parts[key]
 if assembly.count!=frame.count or assembly.hash!=frame.hash:parts.erase(key);return false
 if not assembly.parts.has(frame.index):assembly.size+=frame.data.size()
 if assembly.size>MAX_PACKED:parts.erase(key);return false
 assembly.parts[frame.index]=frame.data
 if assembly.parts.size()!=assembly.count:return false
 var data=PackedByteArray()
 for index in range(assembly.count):data.append_array(assembly.parts[index])
 parts.erase(key)
 if data.size()<4 or data[0]!=TYPE_DICTIONARY or data.hex_encode().sha256_text()!=assembly.hash:return false
 var message=bytes_to_var(data)
 if message is Dictionary and message.get("compressed") is PackedByteArray:
  if not message.get("raw_size") is int or message.raw_size<4 or message.raw_size>MAX_RAW:return false
  data=message.compressed.decompress(message.raw_size,FileAccess.COMPRESSION_ZSTD)
  if data.size()!=message.raw_size or data[0]!=TYPE_DICTIONARY:return false
  message=bytes_to_var(data)
 if not message is Dictionary or not message.get("room") is Dictionary:return false
 var public_room=message.room
 if public_room.get("status","") not in ["playing","complete"]:return false
 var leaders=public_room.get("leaders",[])
 if not leaders is Array or leaders.size()!=2:return false
 for leader in leaders:
  if not leader is String or leader.is_empty() or leader.length()>128:return false
 var absolute=ProjectSettings.globalize_path(log_path)
 if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())!=OK:return false
 var file=FileAccess.open(absolute,FileAccess.READ_WRITE if FileAccess.file_exists(absolute) else FileAccess.WRITE)
 if file==null:return false
 file.seek_end()
 file.store_string(JSON.stringify({"match_id":room.match_id,"leaders":leaders,"recorded_at":int(Time.get_unix_time_from_system()),"source":"host_public_room"})+"\n")
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK:return false
 room._character_recorded=true;room.erase("_character_parts")
 return true
