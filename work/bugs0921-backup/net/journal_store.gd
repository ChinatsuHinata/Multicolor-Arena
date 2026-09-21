extends RefCounted
## Check the magic and checksum before Variant decoding; keep a previous generation.
const MAGIC="MLCJ1\n"
static func save_to(path: String,data: Dictionary) -> Error:
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var bytes=var_to_bytes(data);var f=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if f==null:return FileAccess.get_open_error()
 f.store_buffer((MAGIC+bytes.hex_encode().sha256_text()+"\n").to_utf8_buffer());f.store_buffer(bytes);f.flush()
 var err=f.get_error();f.close()
 if err!=OK:return err
 if FileAccess.file_exists(path):
  err=DirAccess.copy_absolute(path,path+".bak")
  if err!=OK:return err
 return DirAccess.rename_absolute(path+".tmp",path)
static func load_from(path: String) -> Dictionary:
 for name in [path,path+".bak"]:
  if not FileAccess.file_exists(name):continue
  var bytes=FileAccess.get_file_as_bytes(name)
  if bytes.size()<75 or bytes.size()>64*1024*1024:continue
  if bytes.slice(0,6).get_string_from_utf8()!=MAGIC or bytes[70]!=10:continue
  var payload=bytes.slice(71)
  if bytes.slice(6,70).get_string_from_utf8()!=payload.hex_encode().sha256_text():continue
  if payload[0]!=TYPE_DICTIONARY:continue
  var data=bytes_to_var(payload)
  if data is Dictionary:return data
 return {}
