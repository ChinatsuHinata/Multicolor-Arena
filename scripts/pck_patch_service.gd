extends Node
## Signed, self-contained PCK patches. The fixed header is deliberately outside
## the Godot pack so its base version can be checked before mounting any code.
const HEADER_SIZE=4096
const MAGIC="MCA-PCK1"
const PUBLIC_KEY="res://data/update_public.pem"
const CHUNK_SIZE=1024*1024
var patch_dir="user://patches"
var base_version=""
var active_version=""
var pending_version=""
var startup_error=""
var trusted_key: CryptoKey

func _init(load_patches: bool=true):
 base_version=str(ProjectSettings.get_setting("application/config/version",""))
 active_version=base_version
 if OS.has_feature("editor") or not load_patches:return
 _load_installed()

func _load_installed() -> void:
 var entries=_read_index()
 if not startup_error.is_empty():return
 var key=_public_key()
 if key==null:
  startup_error="补丁公钥不可用。"
  return
 for name in entries:
  var path=patch_dir+"/"+name
  var result=inspect(path,"",key)
  if result.has("error"):
   startup_error="已安装补丁无法加载："+result.error
   break
  if result.from!=active_version:
   if result.from==base_version and _newer(result.to,active_version):
    pass
   elif result.to==active_version or _newer(active_version,result.to):continue
   else:
    startup_error="已安装补丁基底版本不匹配：当前 %s，补丁要求 %s。" % [active_version,result.from]
    break
  if not ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(path),true,HEADER_SIZE):
   startup_error="已安装补丁挂载失败："+name
   break
  active_version=result.to
 ProjectSettings.set_setting("application/config/version",active_version)

func platform() -> String:
 return "android" if OS.has_feature("android") else "windows"

func _public_key() -> CryptoKey:
 if trusted_key!=null:return trusted_key
 var key=CryptoKey.new()
 if key.load(PUBLIC_KEY,true)!=OK:return null
 trusted_key=key
 return trusted_key

func _read_index() -> Array:
 var index_path=patch_dir+"/index.json"
 if not FileAccess.file_exists(index_path):return []
 var data=JSON.parse_string(FileAccess.get_file_as_string(index_path))
 if not data is Array:
  startup_error="补丁记录已损坏。"
  return []
 for name in data:
  if not name is String or not name.is_valid_filename() or not name.ends_with(".pck"):
   startup_error="补丁记录含无效文件名。"
   return []
 return data

func inspect(path: String, expected_from: String, key: CryptoKey=null) -> Dictionary:
 var f=FileAccess.open(path,FileAccess.READ)
 if f==null:return {"error":"无法读取 PCK："+path}
 if f.get_length()<=HEADER_SIZE:return {"error":"PCK 文件不完整。"}
 if f.get_buffer(8).get_string_from_ascii()!=MAGIC:return {"error":"不是本游戏支持的签名 PCK 补丁。"}
 var header_length=f.get_32()
 if header_length<=0 or header_length>HEADER_SIZE-12:return {"error":"PCK 补丁头无效。"}
 var envelope=JSON.parse_string(f.get_buffer(header_length).get_string_from_utf8())
 if not envelope is Dictionary or not envelope.get("payload") is String or not envelope.get("signature") is String:
  return {"error":"PCK 补丁签名数据无效。"}
 var payload_bytes=Marshalls.base64_to_raw(envelope.payload)
 var signature=Marshalls.base64_to_raw(envelope.signature)
 if payload_bytes.is_empty() or signature.is_empty():return {"error":"PCK 补丁签名缺失。"}
 if key==null:key=_public_key()
 if key==null:return {"error":"补丁公钥不可用。"}
 var h=HashingContext.new()
 h.start(HashingContext.HASH_SHA256)
 h.update(payload_bytes)
 if not Crypto.new().verify(HashingContext.HASH_SHA256,h.finish(),signature,key):
  return {"error":"PCK 补丁签名校验失败。"}
 var payload=JSON.parse_string(payload_bytes.get_string_from_utf8())
 if not payload is Dictionary:return {"error":"PCK 补丁信息无效。"}
 if payload.get("format")!="multicolor:arena/pck-patch-1" or payload.get("game")!="multicolor:arena":
  return {"error":"PCK 补丁不属于本游戏。"}
 if payload.get("platform")!=platform():return {"error":"此补丁不适用于当前平台。"}
 if not payload.get("from") is String or (not expected_from.is_empty() and payload.from!=expected_from):
  return {"error":"基底版本不匹配：当前 %s，补丁要求 %s。" % [expected_from,str(payload.get("from","未知"))]}
 if not payload.get("to") is String or not _newer(payload.to,payload.from):
  return {"error":"补丁目标版本无效。"}
 if not payload.get("sha256") is String or payload.sha256.length()!=64:
  return {"error":"补丁哈希无效。"}
 if not payload.get("size") is float and not payload.get("size") is int:
  return {"error":"补丁大小无效。"}
 if int(payload["size"])!=f.get_length()-HEADER_SIZE:return {"error":"补丁文件大小不匹配。"}
 f.seek(HEADER_SIZE)
 if f.get_buffer(4).get_string_from_ascii()!="GDPC":return {"error":"补丁不包含有效的 Godot PCK。"}
 f.seek(HEADER_SIZE)
 var pack_hash=HashingContext.new()
 pack_hash.start(HashingContext.HASH_SHA256)
 while f.get_position()<f.get_length():
  var remaining=f.get_length()-f.get_position()
  var part=f.get_buffer(mini(CHUNK_SIZE,remaining))
  if part.is_empty():return {"error":"补丁读取中断。"}
  pack_hash.update(part)
 if pack_hash.finish().hex_encode()!=payload.sha256.to_lower():return {"error":"PCK 补丁内容校验失败。"}
 return {"from":payload.from,"to":payload.to,"sha256":payload.sha256.to_lower()}

func _newer(to_version: String, from_version: String) -> bool:
 var to_parts=to_version.split(".")
 var from_parts=from_version.split(".")
 if to_parts.size()<3 or to_parts.size()>4 or from_parts.size()<3 or from_parts.size()>4:return false
 for part in to_parts+from_parts:
  if part.is_empty() or not part.is_valid_int() or part.length()>5:return false
 for i in range(4):
  var old=int(from_parts[i]) if i<from_parts.size() else 0
  var new=int(to_parts[i]) if i<to_parts.size() else 0
  if new>old:return true
  if new<old:return false
 return false

func install(source_path: String) -> Dictionary:
 return install_chain([source_path])

func installed_version() -> String:
 return pending_version if _newer(pending_version,active_version) else active_version

func install_chain(source_paths: Array) -> Dictionary:
 if not startup_error.is_empty():return {"error":startup_error}
 if source_paths.is_empty():return {"error":"补丁链为空。"}
 var current=installed_version()
 var verified=[]
 for source_path in source_paths:
  var details=inspect(source_path,"")
  if details.has("error"):return details
  if details.from!=current and (not verified.is_empty() or details.from!=base_version):
   return {"error":"基底版本不匹配：当前 %s，补丁要求 %s。" % [current,details.from]}
  if not _newer(details.to,current):return {"error":"补丁不是更新版本。"}
  verified.append(details)
  current=details.to
 var previous_entries=_read_index()
 if not startup_error.is_empty():return {"error":startup_error}
 var entries=previous_entries.duplicate() if verified[0].from==installed_version() else []
 var folder=patch_dir
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK:
  return {"error":"无法创建补丁目录。"}
 var created=[]
 for i in range(source_paths.size()):
  var details=verified[i]
  var name=details.from+"-to-"+details.to+"-"+details.sha256+".pck"
  var destination=folder+"/"+name
  var temporary=destination+".tmp"
  var source=FileAccess.open(source_paths[i],FileAccess.READ)
  var output=FileAccess.open(temporary,FileAccess.WRITE)
  if source==null or output==null:
   if source!=null:source.close()
   if output!=null:output.close()
   _remove_files(created+[temporary])
   return {"error":"无法复制补丁到游戏数据目录。"}
  while source.get_position()<source.get_length():
   var part=source.get_buffer(mini(CHUNK_SIZE,source.get_length()-source.get_position()))
   if part.is_empty():break
   output.store_buffer(part)
  output.close()
  source.close()
  var copied=inspect(temporary,details.from)
  if copied.has("error") or copied.get("to")!=details.to or copied.get("sha256")!=details.sha256:
   _remove_files(created+[temporary])
   return copied if copied.has("error") else {"error":"复制期间补丁内容发生变化。"}
  if FileAccess.file_exists(destination):
   var existing=inspect(destination,details.from)
   if existing.has("error") or existing.get("to")!=details.to or existing.get("sha256")!=details.sha256:
    _remove_files(created+[temporary])
    return {"error":"已存在的补丁文件校验失败。"}
   _remove_files([temporary])
  elif DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(destination))!=OK:
   _remove_files(created+[temporary])
   return {"error":"无法保存补丁文件。"}
  else:created.append(destination)
  entries.append(name)
 var committed=_write_index(entries)
 if committed!=OK:
  _remove_files(created)
  return {"error":"无法提交补丁记录。"}
 pending_version=current
 for old_name in previous_entries:
  if not old_name in entries:_remove_files([folder+"/"+old_name])
 return {"to":current}

func _write_index(entries: Array) -> Error:
 # The only commit point: until this rename succeeds the old chain stays active.
 var index_path=patch_dir+"/index.json"
 var index_tmp=index_path+".tmp"
 var index_file=FileAccess.open(index_tmp,FileAccess.WRITE)
 if index_file==null:return ERR_CANT_CREATE
 index_file.store_string(JSON.stringify(entries))
 var written=index_file.get_error()
 index_file.close()
 var result=written if written!=OK else DirAccess.rename_absolute(ProjectSettings.globalize_path(index_tmp),ProjectSettings.globalize_path(index_path))
 if result!=OK:_remove_files([index_tmp])
 return result

func _remove_files(paths: Array) -> void:
 for path in paths:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
