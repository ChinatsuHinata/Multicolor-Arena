extends SceneTree

func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1:
  push_error("Expected target version argument")
  quit(2)
  return
 var actual=str(ProjectSettings.get_setting("application/config/version",""))
 if actual!=args[0]:
  push_error("PCK target version mismatch: "+actual+" != "+args[0])
  quit(2)
  return
 print("PCK_TARGET_VERSION: ",actual)
 quit(0)
