extends SceneTree

func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size()!=4:quit(2);return
 var folder=args[0]
 var source_version=args[1]
 var runtime_script=args[2]
 var key: CryptoKey
 var key_path=folder.path_join("test-signing.key")
 if FileAccess.file_exists(key_path):
  key=CryptoKey.new()
  if key.load(key_path)!=OK:quit(2);return
 else:key=Crypto.new().generate_rsa(2048)
 if key==null or key.save(folder.path_join("test-signing.key"))!=OK or key.save(folder.path_join("test-public.pem"),true)!=OK:
  push_error("Cannot create isolated test key");quit(2);return
 # Clone the already verified installed chain, retaining its exact resource bytes.
 # Test signatures allow this copy to coexist with the new test delta under one trust root.
 var sources=JSON.parse_string(FileAccess.get_file_as_string(args[3]))
 if not sources is Array:quit(2);return
 var patch_folder=folder.path_join("profile/Godot/app_userdata/MulticolorArena-TEST_ONLY/patches")
 DirAccess.make_dir_recursive_absolute(patch_folder)
 var entries=[]
 for i in range(sources.size()):
  var source=FileAccess.open(sources[i],FileAccess.READ)
  if source==null:quit(2);return
  source.seek(8)
  var envelope=JSON.parse_string(source.get_buffer(source.get_32()).get_string_from_utf8())
  var claims=JSON.parse_string(Marshalls.base64_to_raw(envelope.payload).get_string_from_utf8())
  claims.test_only=true;claims.TEST_ONLY=true
  var bytes=JSON.stringify(claims).to_utf8_buffer()
  var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
  var signature=Crypto.new().sign(HashingContext.HASH_SHA256,hash.finish(),key)
  var header=JSON.stringify({"payload":Marshalls.raw_to_base64(bytes),"signature":Marshalls.raw_to_base64(signature)}).to_utf8_buffer()
  if header.size()>4084:quit(2);return
  var name="TEST_ONLY-source-%d.pck" % i
  var output=FileAccess.open(patch_folder.path_join(name),FileAccess.WRITE)
  if output==null:quit(2);return
  output.store_buffer("MCA-PCK1".to_ascii_buffer());output.store_32(header.size());output.store_buffer(header)
  var padding=PackedByteArray();padding.resize(4084-header.size());output.store_buffer(padding)
  source.seek(4096)
  while source.get_position()<source.get_length():output.store_buffer(source.get_buffer(mini(1024*1024,source.get_length()-source.get_position())))
  output.close();source.close();entries.append(name)
 var index=FileAccess.open(patch_folder.path_join("index.json"),FileAccess.WRITE)
 index.store_string(JSON.stringify(entries));index.close()
 var project='[application]\nconfig/name="MulticolorArena TEST_ONLY"\nconfig/version="%s"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Godot/app_userdata/MulticolorArena-TEST_ONLY"\nrun/main_scene="res://pck_update_probe.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n' % source_version
 var files={
  "project.godot":project,
  ".godot/global_script_class_cache.cfg":"list=[]\n",
  "pck_update_probe.tscn":'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://pck_update_probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript=ExtResource("1")\n',
  "pck_update_probe.gd":FileAccess.get_file_as_string(runtime_script),
  "data/update_public.pem":key.save_to_string(true),
  "TEST_ONLY.txt":"Isolated update test; never distribute or publish."
 }
 var pack=PCKPacker.new()
 if pack.pck_start(folder.path_join("UpdateProbe.pck"))!=OK:quit(2);return
 for name in files:
  var path=folder.path_join("harness").path_join(name)
  DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  var output=FileAccess.open(path,FileAccess.WRITE)
  if output==null:quit(2);return
  output.store_string(files[name]);output.close()
  if pack.add_file("res://"+name,path)!=OK:quit(2);return
 quit(0 if pack.flush()==OK else 2)
