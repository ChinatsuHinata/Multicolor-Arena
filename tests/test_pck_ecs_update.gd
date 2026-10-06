extends SceneTree

# Manual integration probe against the published ECS update endpoint.
var failures=[]
var starts=[]
var progress=[]
var outcome={}

func _initialize():call_deferred("run")

func check(value: bool,description: String) -> void:
 if value:print("PASS: ",description)
 else:failures.append(description);push_error(description)

func run() -> void:
 var base=load("res://scripts/pck_auto_updater.gd").BASE_VERSION
 var folder=ProjectSettings.globalize_path("res://work/pck-ecs-update-test")
 DirAccess.make_dir_recursive_absolute(folder)
 var manager=root.get_node("PatchManager")
 manager.patch_dir=folder
 manager.base_version=base
 manager.active_version=base
 manager.pending_version=""
 var app=load("res://main.tscn").instantiate()
 app.auto_patch_update_in_editor=true
 root.add_child(app)
 await process_frame
 app.account_name="ecs_probe"
 app.check_cloud_pck_patch()
 var updater=app.auto_pck_updater
 updater.download_started.connect(func(total,count):
  starts.append({"total":total,"count":count})
  check(is_instance_valid(app.auto_patch_dialog) and app.auto_patch_dialog.visible,"ECS download opens progress dialog")
  app.auto_patch_dialog.hide()
  app.online()
  var lobby=app.screen.get_children().filter(func(child):return child.get_script()==load("res://net/lan_lobby.gd"))[0]
  lobby.set_cloud_mode(true)
  check(not lobby.cloud_selected and app.auto_patch_dialog.visible,"hidden progress still blocks cloud entry"))
 updater.download_progress.connect(func(done,total,stage):progress.append({"done":done,"total":total,"stage":stage}))
 updater.completed.connect(func(result):outcome=result)
 var deadline=Time.get_ticks_msec()+120000
 while updater.busy and Time.get_ticks_msec()<deadline:
  await process_frame
 check(not updater.busy,"ECS update request completes")
 check(not starts.is_empty() and starts[0].total>4096,"ECS manifest selects a real patch")
 check(not progress.is_empty() and progress.back().done==progress.back().total,"ECS download reaches full progress")
 check(outcome.get("installed",false),"ECS patch verifies and installs: "+str(outcome))
 check(app.auto_patch_restart_required and app.cloud_match_blocked(),"cloud entry remains blocked until restart")
 check(manager.pending_version==str(outcome.get("version","")),"installed version matches the signed manifest")
 app.queue_free()
 await process_frame
 var dir=DirAccess.open(folder)
 if dir!=null:
  for name in dir.get_files():DirAccess.remove_absolute(folder.path_join(name))
 DirAccess.remove_absolute(folder)
 print("PCK_ECS_UPDATE: ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
