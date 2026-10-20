extends Node
func _ready():
 print("MOD_IMPORT_DEVICE: starting on ",OS.get_name())
 call_deferred("run")
func run():
 var code=preload("res://tests/support/mod_import_suite.gd").new().run()
 if code!=0:finish(code);return
 preload("res://scripts/portable_paths.gd").root_override=""
 call_deferred("open_picker")
func open_picker():
 var picker=FileDialog.new()
 picker.access=FileDialog.ACCESS_FILESYSTEM;picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE;picker.use_native_dialog=true
 picker.filters=PackedStringArray(["*.zip ; ZIP 模组文件"])
 add_child(picker)
 picker.file_selected.connect(func(path):
  print("MOD_IMPORT_NATIVE: selected ",path)
  var importer=preload("res://scripts/mod_importer.gd")
  var registry=preload("res://scripts/rules/mod_registry.gd")
  var result=importer.import_file(path,registry.configuration())
  if result.has("error"):push_error(str(result));finish(1);return
  var duplicate=importer.import_file(path,registry.configuration())
  var ok=FileAccess.file_exists(result.path.path_join("manifest.json")) and duplicate.get("error","").contains("相同模组")
  print("MOD_IMPORT_NATIVE: installed=",result.path," duplicate_rejected=",ok)
  finish(0 if ok else 1))
 picker.canceled.connect(func():finish(1))
 print("MOD_IMPORT_NATIVE: awaiting selection")
 picker.popup_centered_ratio(0.8)
func finish(code: int):
 var result=FileAccess.open("user://mod-import-device-result.txt",FileAccess.WRITE)
 result.store_string(str(code));result.close()
 print("MOD_IMPORT_DEVICE: exit=",code)
 get_tree().quit(code)
