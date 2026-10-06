extends SceneTree

var failures=[]

func _initialize():call_deferred("run")

func check(value: bool,description: String) -> void:
 if value:print("PASS: ",description)
 else:failures.append(description);push_error(description)

func run() -> void:
 var app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.auto_patch_check_pending=true
 app.cloud_pck_download_started(4*1024*1024,2)
 check(is_instance_valid(app.auto_patch_dialog) and app.auto_patch_dialog.visible,"download dialog opens automatically")
 app.cloud_pck_download_progress(1024*1024,4*1024*1024,"正在下载补丁 1/2")
 check(app.auto_patch_progress.value==1024*1024 and app.auto_patch_status.text.contains("25%"),"dialog shows aggregate byte progress")
 app.auto_patch_dialog.hide()
 check(app.auto_patch_reopen.visible,"hidden dialog leaves a progress shortcut")
 app.online()
 var lobby=app.screen.get_children().filter(func(child):return child.get_script()==load("res://net/lan_lobby.gd"))[0]
 lobby.set_cloud_mode(true)
 check(not lobby.cloud_selected and app.auto_patch_dialog.visible,"cloud entry is blocked and reopens progress")
 lobby.create_relay()
 lobby.join_cloud_room({"id":"blocked"},1)
 check(lobby.session.room_id.is_empty() and not lobby.session.joining,"existing cloud room controls cannot create or join during update")
 app.auto_patch_check_pending=false
 app.cloud_pck_patch_completed({"error":"simulated download failure"})
 check(not app.cloud_match_blocked() and not is_instance_valid(app.auto_patch_dialog),"failed update releases cloud entry and closes progress")
 app.cloud_pck_patch_completed({"installed":true,"version":"1.2.7.9"})
 check(app.cloud_match_blocked(),"installed update keeps cloud entry blocked until restart")
 app.queue_free()
 await process_frame
 print("PCK_DOWNLOAD_UI: ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
