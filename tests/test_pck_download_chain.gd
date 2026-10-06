extends SceneTree
## Real HTTP downloads against an isolated gateway. Versions are supplied by the fixture.
const Fixture=preload("res://tests/support/pck_download_fixture.gd")
const Inspector=preload("res://tools/support/pck_platform_inspector.gd")
const Updater=preload("res://scripts/pck_auto_updater.gd")
var failures=[]
var checks=0
var folder=""
var origin=""
var metadata: Dictionary
var key: CryptoKey
var manager
var updater
var outcomes=[]
var results=[]

func _initialize():call_deferred("run")

func check(ok: bool,label: String) -> void:
 checks+=1
 if ok:print("PASS: ",label)
 else:failures.append(label);push_error(label)

func http(path: String) -> Dictionary:
 var request=HTTPRequest.new()
 request.timeout=10.0
 root.add_child(request)
 var reply=[]
 request.request_completed.connect(func(result,code,_headers,body):reply.append({"result":result,"code":code,"body":body}))
 var error=request.request(origin+path)
 if error!=OK:
  request.queue_free()
  return {"result":error,"code":0,"body":PackedByteArray()}
 while reply.is_empty():await process_frame
 request.queue_free()
 return reply[0]

func scenario(name: String) -> void:
 var reply=await http("/__test__/set/"+name)
 check(reply.code==200,"private scenario "+name)

func requested() -> Array:
 var reply=await http("/__test__/log")
 return JSON.parse_string(reply.body.get_string_from_utf8()) if reply.code==200 else []

func download() -> Dictionary:
 outcomes.clear()
 updater.check_for_update(manager)
 var deadline=Time.get_ticks_msec()+30000
 while outcomes.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
 if outcomes.is_empty():
  check(false,"cloud download completes within deadline")
  return {"error":"test deadline"}
 return outcomes[0]

func reset(platform: String,start: String) -> void:
 if is_instance_valid(updater):updater.free()
 if is_instance_valid(manager):manager.free()
 manager=Inspector.new(false)
 manager.inspect_platform=platform
 manager.base_version=metadata.versions[0];manager.active_version=start
 manager.patch_dir=folder.path_join("installed-"+platform)
 manager.trusted_key=key
 DirAccess.make_dir_recursive_absolute(manager.patch_dir)
 for name in DirAccess.open(manager.patch_dir).get_files():DirAccess.remove_absolute(manager.patch_dir.path_join(name))
 updater=Updater.new()
 updater.origin=origin
 root.add_child(updater)
 updater.completed.connect(func(result):outcomes.append(result))

func files() -> PackedStringArray:
 return DirAccess.open(manager.patch_dir).get_files()

func expected_paths(platform: String,offset: int=0) -> Array:
 var paths=["/updates/pck/chain.json"]
 for i in range(offset,metadata.edges.size()):paths.append(metadata.edges[i][platform].url.trim_prefix(origin))
 return paths

func verify_platform(platform: String) -> void:
 reset(platform,metadata.versions[0])
 var prefix=platform+": "
 var public_manager=Inspector.new(false)
 public_manager.inspect_platform=platform
 var test_patch=folder.path_join("releases/pck/"+metadata.versions[1]).path_join(metadata.edges[0][platform].url.get_file())
 check(public_manager.inspect(test_patch,metadata.versions[0]).has("error"),prefix+"ordinary release key rejects TEST_ONLY PCK")
 var public_updater=Updater.new()
 public_updater.manager=public_manager
 check(public_updater._verify_manifest(FileAccess.get_file_as_bytes(folder.path_join("releases/pck/chain.json"))).has("error"),prefix+"ordinary release key rejects TEST_ONLY manifest")
 public_updater.free();public_manager.free()
 for fault in ["missing-middle","corrupt-middle","truncate-middle","broken-chain"]:
  await scenario(fault)
  var result=await download()
  check(result.has("error"),prefix+fault+" returns an error")
  check(manager.installed_version()==metadata.versions[0] and files().is_empty(),prefix+fault+" preserves version and removes all downloaded files")
  var paths=await requested()
  var expected=expected_paths(platform)
  if fault=="broken-chain":expected=[expected[0]]
  else:expected.resize(3)
  check(paths==expected,prefix+fault+" stops before final patch")
  results.append({"platform":platform,"scenario":fault,"result":result,"requests":paths})
 await scenario("success")
 var result=await download()
 var paths=await requested()
 check(paths==expected_paths(platform),prefix+"downloads all three adjacent PCKs in order over SSH tunnel")
 check(result.get("installed",false) and result.get("patch_count")==3 and result.get("version")==metadata.versions[-1],prefix+"commits all three patches with one completion")
 check(outcomes.size()==1 and manager.active_version==metadata.versions[0] and manager.installed_version()==metadata.versions[-1],prefix+"running version stays unchanged until restart")
 var index_path=manager.patch_dir.path_join("index.json")
 var index=JSON.parse_string(FileAccess.get_file_as_string(index_path))
 check(index is Array and index.size()==3 and files().size()==4,prefix+"atomic index contains three PCKs and no temporary files")
 results.append({"platform":platform,"scenario":"success","result":result,"requests":paths})
 result=await download()
 paths=await requested()
 check(result.get("up_to_date",false) and paths.size()==5 and paths[-1]=="/updates/pck/chain.json",prefix+"pending restart does not redownload any patch")
 var restarted=Inspector.new(false)
 restarted.inspect_platform=platform;restarted.base_version=metadata.versions[0];restarted.active_version=metadata.versions[0]
 restarted.patch_dir=manager.patch_dir;restarted.trusted_key=key
 restarted._load_installed()
 check(restarted.startup_error.is_empty() and restarted.active_version==metadata.versions[-1],prefix+"restart mounts all signed PCKs")
 check(FileAccess.get_file_as_string(Fixture.RESOURCE)=="TEST_ONLY|%s|%s" % [metadata.test_run,metadata.versions[-1]],prefix+"final marker comes from the last patch")
 for version in metadata.versions.slice(1):check(FileAccess.file_exists("res://data/pck_test_only_steps/"+version+".txt"),prefix+"restart preserves marker from "+version)
 restarted.free()
 for i in [1,2]:
  reset(platform,metadata.versions[i])
  await scenario("success")
  result=await download();paths=await requested()
  check(paths==expected_paths(platform,i) and result.get("patch_count")==3-i,prefix+"intermediate client downloads only "+str(3-i)+" missing patches")
 reset(platform,metadata.versions[0])
 var seed=manager.install(test_patch)
 check(seed.get("to")==metadata.versions[1],prefix+"seed an existing installed patch")
 manager.active_version=metadata.versions[1];manager.pending_version=""
 var original_index=FileAccess.get_file_as_string(index_path)
 var original_files=files()
 await scenario("missing-middle")
 result=await download()
 check(result.has("error") and FileAccess.get_file_as_string(index_path)==original_index and files()==original_files,prefix+"failed upgrade preserves existing index and PCK")
 await scenario("success")
 result=await download()
 check(result.get("patch_count")==2 and manager.installed_version()==metadata.versions[-1],prefix+"retry recovers and installs the remaining chain")
 for name in files():DirAccess.remove_absolute(manager.patch_dir.path_join(name))
 check(files().is_empty(),prefix+"cleanup removes installed virtual patches")
 DirAccess.remove_absolute(manager.patch_dir)

func run() -> void:
 var args=OS.get_cmdline_user_args()
 if args.size()<3 or args[0] not in ["--prepare","--run"]:
  push_error("Expected --prepare/--run TEST_ONLY_folder loopback_origin [four versions]");quit(2);return
 folder=ProjectSettings.globalize_path(args[1]);origin=args[2]
 if not folder.get_file().begins_with("TEST_ONLY-") or not origin.begins_with("http://127.0.0.1:"):
  push_error("Fixtures require a TEST_ONLY directory and a loopback origin");quit(2);return
 if args[0]=="--prepare":
  if args.size()!=7:quit(2);return
  DirAccess.make_dir_recursive_absolute(folder)
  var fixture=Fixture.new();fixture.folder=folder;fixture.origin=origin
  fixture.prepare(args.slice(3))
  print("TEST_ONLY_FIXTURES_READY: ",folder);quit(0);return
 metadata=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("TEST_ONLY.json")))
 if metadata.get("test_only")!=true or metadata.get("origin")!=origin or metadata.get("versions",[]).size()!=4:
  push_error("Invalid TEST_ONLY metadata");quit(2);return
 key=CryptoKey.new()
 if key.load(folder.path_join("test_public.pem"),true)!=OK:quit(2);return
 var original_version=ProjectSettings.get_setting("application/config/version")
 for platform in ["windows","android"]:await verify_platform(platform)
 ProjectSettings.set_setting("application/config/version",original_version)
 updater.free();manager.free()
 var report={"test_only":true,"test_run":metadata.test_run,"checks":checks,"failures":failures,"results":results,"android_execution":"platform simulated on Windows Godot"}
 var file=FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("PCK_DOWNLOAD_CHAIN: ","PASS" if failures.is_empty() else "FAIL"," (",checks," checks)")
 quit(0 if failures.is_empty() else 1)
