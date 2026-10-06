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
 var app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.settings()
 check(find_button(app.screen,"加载 PCK 补丁…")!=null,"desktop settings offers PCK import")
 app.is_android=true
 app.settings()
 check(find_button(app.screen,"加载 PCK 补丁…")!=null,"Android settings offers PCK import")
 app.queue_free()
 await process_frame
 print("PCK_PATCH_UI: ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
