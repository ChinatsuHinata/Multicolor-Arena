extends SceneTree
const Inspector=preload("res://tools/support/pck_platform_inspector.gd")

func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size()!=4:push_error("Expected PCK path, source version, target version and platform");quit(2);return
 var manager=Inspector.new()
 # Inspect either platform without mounting its resources on this host.
 manager.inspect_platform=args[3]
 var details=manager.inspect(args[0],args[1])
 manager.free()
 if details.has("error") or details.get("to")!=args[2]:push_error("Signed PCK version/platform/content mismatch: "+str(details));quit(2);return
 quit(0)
