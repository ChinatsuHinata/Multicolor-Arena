extends SceneTree
const Patch=preload("res://tests/support/patch_commit_failure.gd")
const FROM_VERSION="8.8.8"
const TO_VERSION="8.8.8.1"

var failures=[]
var manager
var folder=""
var raw=""
var wrapped=""
var marker=""

func _initialize():call_deferred("run")

func check(value: bool,description: String):
 if value:print("PASS: ",description)
 else:failures.append(description);push_error(description)

func signed_pack(key: CryptoKey,from_version: String,to_version: String,for_platform: String,hash_override: String="") -> void:
 var payload={"format":"multicolor:arena/pck-patch-1","game":"multicolor:arena","platform":for_platform,"from":from_version,"to":to_version,"sha256":FileAccess.get_sha256(raw) if hash_override.is_empty() else hash_override,"size":FileAccess.open(raw,FileAccess.READ).get_length()}
 var bytes=JSON.stringify(payload).to_utf8_buffer()
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
 var signature=Crypto.new().sign(HashingContext.HASH_SHA256,hash.finish(),key)
 var envelope=JSON.stringify({"payload":Marshalls.raw_to_base64(bytes),"signature":Marshalls.raw_to_base64(signature)}).to_utf8_buffer()
 var output=FileAccess.open(wrapped,FileAccess.WRITE)
 output.store_buffer("MCA-PCK1".to_ascii_buffer())
 output.store_32(envelope.size())
 output.store_buffer(envelope)
 var padding=PackedByteArray();padding.resize(4096-12-envelope.size());output.store_buffer(padding)
 var input=FileAccess.open(raw,FileAccess.READ)
 output.store_buffer(input.get_buffer(input.get_length()))
 output.close()

func run():
 manager=Patch.new()
 folder=ProjectSettings.globalize_path("res://work/patch-test")
 DirAccess.make_dir_recursive_absolute(folder)
 raw=folder.path_join("source.pck")
 wrapped=folder.path_join("signed.pck")
 marker=folder.path_join("marker.txt")
 var file=FileAccess.open(marker,FileAccess.WRITE);file.store_string("PCK patch mounted");file.close()
 var pack=PCKPacker.new()
 check(pack.pck_start(raw)==OK,"create test PCK")
 check(pack.add_file("res://data/pck_patch_probe.txt",marker)==OK,"add test resource")
 check(pack.flush()==OK,"finish test PCK")
 var key=Crypto.new().generate_rsa(2048)
 signed_pack(key,FROM_VERSION,TO_VERSION,manager.platform())
 var accepted=manager.inspect(wrapped,FROM_VERSION,key)
 check(accepted.get("to")==TO_VERSION,"matching base version is accepted")
 check(manager.inspect(wrapped,"8.8.7",key).has("error"),"wrong base version is rejected")
 check(manager.inspect(wrapped,TO_VERSION,key).has("error"),"already upgraded version is rejected")
 check(ProjectSettings.load_resource_pack(wrapped,true,4096),"signed wrapper mounts at PCK offset")
 check(FileAccess.get_file_as_string("res://data/pck_patch_probe.txt")=="PCK patch mounted","mounted resource is readable")
 signed_pack(key,FROM_VERSION,TO_VERSION,"android" if manager.platform()=="windows" else "windows")
 check(manager.inspect(wrapped,FROM_VERSION,key).has("error"),"wrong platform is rejected")
 signed_pack(key,FROM_VERSION,TO_VERSION,manager.platform(),"0".repeat(64))
 check(manager.inspect(wrapped,FROM_VERSION,key).has("error"),"tampered PCK hash is rejected")
 signed_pack(key,FROM_VERSION,TO_VERSION,manager.platform())
 check(manager.inspect(wrapped,FROM_VERSION,Crypto.new().generate_rsa(2048)).has("error"),"wrong signature is rejected")
 check(not manager._newer(FROM_VERSION,FROM_VERSION) and not manager._newer("8.8.7",FROM_VERSION),"non-upgrades are rejected")
 manager.patch_dir=folder.path_join("installed")
 manager.trusted_key=key
 manager.active_version=FROM_VERSION
 var installation=manager.install(wrapped)
 check(installation.get("to")==TO_VERSION,"verified PCK is installed")
 var index=JSON.parse_string(FileAccess.get_file_as_string(manager.patch_dir.path_join("index.json")))
 check(index is Array and index.size()==1 and FileAccess.file_exists(manager.patch_dir.path_join(index[0])),"installed pack and load order are saved")
 manager.active_version=TO_VERSION
 signed_pack(key,TO_VERSION,"8.8.8.2",manager.platform())
 var second=manager.install(wrapped)
 check(second.get("to")=="8.8.8.2","matching follow-up patch is installed")
 index=JSON.parse_string(FileAccess.get_file_as_string(manager.patch_dir.path_join("index.json")))
 check(index is Array and index.size()==2 and index[0]!=index[1],"patch chain preserves installation order")
 manager.base_version=FROM_VERSION
 manager.active_version="8.8.8.2"
 signed_pack(key,FROM_VERSION,"8.8.8.3",manager.platform())
 var replacement=manager.install(wrapped)
 check(replacement.get("to")=="8.8.8.3","new fixed-base patch replaces the installed version")
 index=JSON.parse_string(FileAccess.get_file_as_string(manager.patch_dir.path_join("index.json")))
 check(index is Array and index.size()==1,"fixed-base update replaces old patch load order")
 var old_index=FileAccess.get_file_as_string(manager.patch_dir.path_join("index.json"))
 var old_files=DirAccess.open(manager.patch_dir).get_files()
 manager.active_version="8.8.8.3"
 signed_pack(key,"8.8.8.3","8.8.8.4",manager.platform())
 var first_source=folder.path_join("chain-first.pck")
 DirAccess.copy_absolute(wrapped,first_source)
 signed_pack(key,"8.8.8.9","8.8.8.10",manager.platform())
 check(manager.install_chain([first_source,wrapped]).has("error") and FileAccess.get_file_as_string(manager.patch_dir.path_join("index.json"))==old_index,"broken batch chain preserves the committed index")
 signed_pack(key,"8.8.8.4","8.8.8.5",manager.platform())
 manager.fail_commit=true
 check(manager.install_chain([first_source,wrapped]).has("error"),"batch reports commit failure")
 check(FileAccess.get_file_as_string(manager.patch_dir.path_join("index.json"))==old_index and DirAccess.open(manager.patch_dir).get_files()==old_files,"failed commit preserves old files and removes new files")
 check(manager.installed_version()=="8.8.8.3","failed batch does not advance pending version")
 manager.fail_commit=false
 var batch=manager.install_chain([first_source,wrapped])
 index=JSON.parse_string(FileAccess.get_file_as_string(manager.patch_dir.path_join("index.json")))
 check(batch.get("to")=="8.8.8.5" and index.size()==3,"batch appends the complete chain in one commit")
 check(manager.active_version=="8.8.8.3" and manager.installed_version()=="8.8.8.5","batch preserves running version and records final pending version")
 DirAccess.remove_absolute(first_source)
 if index is Array:
  for name in index:DirAccess.remove_absolute(manager.patch_dir.path_join(name))
 DirAccess.remove_absolute(manager.patch_dir.path_join("index.json"))
 DirAccess.remove_absolute(manager.patch_dir)
 manager.free()
 for path in [raw,wrapped,marker]:DirAccess.remove_absolute(path)
 DirAccess.remove_absolute(folder)
 print("PCK_PATCH: ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
