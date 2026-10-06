extends SceneTree
## Read the release itself; filenames and the source project's version are not authoritative.

func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1 and args.size()!=3:
  push_error("Expected metadata output path [installed patch directory, snapshot path]")
  quit(2)
  return
 var base=str(ProjectSettings.get_setting("application/config/version",""))
 var active=base
 var patches=[]
 if args.size()==3 and FileAccess.file_exists(args[1].path_join("index.json")):
  var entries=JSON.parse_string(FileAccess.get_file_as_string(args[1].path_join("index.json")))
  if not entries is Array:push_error("Installed patch index is invalid");quit(2);return
  var manager=load("res://scripts/patch_manager.gd").new()
  for name in entries:
   if not name is String or not name.is_valid_filename() or not name.ends_with(".pck"):
    push_error("Invalid installed patch filename");quit(2);return
   var path=args[1].path_join(name)
   var file=FileAccess.open(path,FileAccess.READ)
   if file==null or file.get_buffer(8).get_string_from_ascii()!="MCA-PCK1":push_error("Invalid installed patch header");quit(2);return
   var length=file.get_32()
   if length<=0 or length>4084:push_error("Invalid installed patch header length");quit(2);return
   var envelope=JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
   if not envelope is Dictionary or not envelope.get("payload") is String:push_error("Invalid installed patch envelope");quit(2);return
   var claims=JSON.parse_string(Marshalls.base64_to_raw(envelope.payload).get_string_from_utf8())
   if not claims is Dictionary or not claims.get("from") is String:push_error("Invalid installed patch claims");quit(2);return
   var verified=manager.inspect(path,claims.from)
   if verified.has("error"):push_error(str(verified));quit(2);return
   if not manager._newer(verified.to,active):continue
   if verified.from!=active and verified.from!=base:push_error("Installed patch chain is incomplete");quit(2);return
   if not ProjectSettings.load_resource_pack(path,true,4096):push_error("Cannot mount installed patch");quit(2);return
   patches.append(path)
   active=verified.to
  manager.free()
 ProjectSettings.set_setting("application/config/version",active)
 var metadata={"version":active,"base_version":base,"patches":patches,"public_key":FileAccess.get_file_as_string("res://data/update_public.pem"),"supports_chain":false}
 var updater=load("res://scripts/pck_auto_updater.gd")
 if updater==null:
  push_error("Release PCK has no automatic updater")
  quit(2)
  return
 for method in updater.get_script_method_list():
  if method.name=="_plan":metadata.supports_chain=true
 if args.size()==3 and not patches.is_empty():
  var pack=PCKPacker.new()
  if pack.pck_start(args[2])!=OK or not _add_resources("res://",pack) or pack.flush()!=OK:
   push_error("Cannot reconstruct the installed full PCK");quit(2);return
 var output=FileAccess.open(args[0],FileAccess.WRITE)
 if output==null:
  push_error("Cannot write PCK metadata")
  quit(2)
  return
 output.store_string(JSON.stringify(metadata))
 output.close()
 print("PCK_SOURCE_VERSION: ",metadata.version," chain=",metadata.supports_chain)
 quit(0)

func _add_resources(folder: String,pack: PCKPacker) -> bool:
 var directory=DirAccess.open(folder)
 if directory==null:return false
 directory.include_hidden=true
 for name in directory.get_files():
  var path=folder.path_join(name)
  if pack.add_file(path,path)!=OK:return false
 for name in directory.get_directories():
  if not _add_resources(folder.path_join(name),pack):return false
 return true
