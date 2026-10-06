extends Node
## Runs inside an exact copy of the installed release executable.

class ProbeAccount:
 extends Node
 var session_token="TEST_ONLY"
 var remember_token="a".repeat(64)
 var nickname="TEST_ONLY"

var results=[]

func _ready():call_deferred("run")

func fail(message: String):
 push_error(message)
 get_tree().quit(1)

func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=5 or OS.has_feature("editor"):
  fail("Expected release runtime, source pack, local origin, test version and mode");return
 var source=args[0]
 var origin=args[1]
 var target=args[2]
 var mode=args[3]
 var source_version=args[4]
 if not origin.begins_with("http://127.0.0.1:") or not ProjectSettings.load_resource_pack(source,false):
  fail("Test must use a loopback server and the installed release PCK");return
 # The harness supplies only the test trust root; all game code comes from the release.
 var manager=load("res://scripts/patch_manager.gd").new()
 manager.name="PatchManager"
 get_tree().root.add_child(manager)
 if not manager.startup_error.is_empty():fail(manager.startup_error);return
 print("TEST_ONLY_RUNTIME: mode=",mode," base=",manager.base_version," active=",manager.active_version," editor=",OS.has_feature("editor")," user_data=",OS.get_user_data_dir())
 var initial_index=JSON.parse_string(FileAccess.get_file_as_string("user://patches/index.json"))
 var source_count=initial_index.size() if initial_index is Array else 0
 if mode=="login" and manager.active_version!=source_version:
  fail("Cloned installation does not match the actual installed release");return
 if mode=="restart":
  if manager.active_version!=target or str(ProjectSettings.get_setting("application/config/version",""))!=target:
   fail("Automatic update did not survive restart");return
  var marker=JSON.parse_string(FileAccess.get_file_as_string("res://data/pck_virtual_version.json"))
  if not marker is Dictionary or marker.get("TEST_ONLY")!=true or marker.get("version")!=target:
   fail("Restart did not mount actual test resources");return
  var inventory=JSON.parse_string(FileAccess.get_file_as_string(OS.get_executable_path().get_base_dir().path_join("target-inventory.json")))
  if not inventory is Dictionary:fail("Target inventory missing");return
  for path in inventory:
   if FileAccess.get_md5(path)!=inventory[path]:fail("Patched release differs from full target: "+path);return
  print("TEST_ONLY_SNAPSHOT_MATCH: ",inventory.size()," target resources match byte for byte")
 var app=load("res://main.tscn").instantiate()
 app.auto_pck_origin=origin
 app.account_session_path="user://TEST_ONLY-session.json"
 get_tree().root.add_child(app)
 app.account_client=ProbeAccount.new()
 app.add_child(app.account_client)
 app.account_action="login"
 app.account_request_finished(true,"TEST_ONLY successful login callback","TEST_ONLY")
 var deadline=Time.get_ticks_msec()+120000
 while Time.get_ticks_msec()<deadline:
  if is_instance_valid(app.auto_pck_updater):break
  await get_tree().process_frame
 if not is_instance_valid(app.auto_pck_updater):fail("Login did not start the automatic updater");return
 app.auto_pck_updater.completed.connect(func(result):results.append(result))
 while results.is_empty() and Time.get_ticks_msec()<deadline:
  await get_tree().create_timer(0.02).timeout
 if results.is_empty():fail("Automatic update timed out");return
 var result=results[0]
 print("TEST_ONLY_UPDATE_RESULT: ",result)
 if mode=="login":
  if not result.get("installed",false) or result.get("version")!=target:
   fail("Released login updater did not install the test patch");return
  var index=JSON.parse_string(FileAccess.get_file_as_string("user://patches/index.json"))
  if not index is Array or index.size()!=source_count+1:fail("Signed patch was not committed after the existing chain");return
  var details=manager.inspect("user://patches/"+index[-1],source_version)
  if details.has("error") or details.get("to")!=target:fail("Installed signed PCK failed inspection");return
 elif not result.get("up_to_date",false):fail("Updated client is not recognised as current");return
 print("INSTALLED_PCK_AUTO_UPDATE: PASS ",mode)
 get_tree().quit(0)
