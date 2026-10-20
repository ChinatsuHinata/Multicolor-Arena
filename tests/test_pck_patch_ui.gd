extends SceneTree

var failures=[]

func _initialize():call_deferred("run")

func find_button(node: Node,caption: String) -> Button:
 if node is Button and node.text==caption:return node
 for child in node.get_children():
  var found=find_button(child,caption)
  if found!=null:return found
 return null

func check(value: bool,description: String):
 if value:print("PASS: ",description)
 else:failures.append(description);push_error(description)

func run():
 var fixture=ProjectSettings.globalize_path("user://pck-settings-ui")
 preload("res://scripts/portable_paths.gd").root_override=fixture
 var registry=preload("res://scripts/rules/mod_registry.gd")
 registry._shared=registry.new()
 var app=load("res://main.tscn").instantiate()
 app.settings_path=fixture.path_join("settings.json")
 app.account_session_path=fixture.path_join("account.json")
 app.tutorial_local_directory=fixture.path_join("tutorials")
 root.add_child(app)
 await process_frame
 app.settings()
 check(find_button(app.screen,"加载 PCK 补丁…")==null,"desktop settings hides manual PCK import")
 app.is_android=true
 app.settings()
 check(find_button(app.screen,"加载 PCK 补丁…")==null,"Android settings hides manual PCK import")
 app.queue_free()
 await process_frame
 print("PCK_PATCH_UI: ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
