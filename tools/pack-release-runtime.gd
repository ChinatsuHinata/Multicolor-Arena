extends SceneTree
## A tiny harness mounts the unchanged release PCK in the release executable.
func _initialize():
 var output=""
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
 if not output.is_absolute_path():quit(1);return
 DirAccess.make_dir_recursive_absolute(output)
 var files={
  ".godot/global_script_class_cache.cfg":"list=[]\n",
  "project.godot":'[application]\nconfig/name="Release Deck Verification"\nrun/main_scene="res://runtime_probe.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
  "runtime_probe.tscn":'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://runtime_bootstrap.gd" id="1"]\n[node name="RuntimeProbe" type="Node"]\nscript = ExtResource("1")\n',
  "runtime_bootstrap.gd":'extends Node\nfunc _ready():\n var packed=""\n for arg in OS.get_cmdline_user_args():\n  if arg.begins_with("--release-pack="):packed=arg.trim_prefix("--release-pack=")\n if packed.is_empty() or not ProjectSettings.load_resource_pack(packed,false):\n  push_error("Cannot mount release PCK");get_tree().quit(1);return\n var test=load("res://runtime_deck_test.gd").new()\n add_child(test)\n',
  "runtime_deck_test.gd":FileAccess.get_file_as_string("res://tests/test_release_deck_runtime.gd")
 }
 var pack=PCKPacker.new()
 if pack.pck_start(output.path_join("RuntimeProbe.pck"))!=OK:quit(1);return
 for name in files:
  var path=output.path_join(name)
  DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  var file=FileAccess.open(path,FileAccess.WRITE)
  file.store_string(files[name]);file.close()
  if pack.add_file("res://"+name,path)!=OK:quit(1);return
 quit(0 if pack.flush()==OK else 1)
