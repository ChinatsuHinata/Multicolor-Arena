extends RefCounted
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Importer=preload("res://scripts/mod_importer.gd")

static func apply_configuration(config: Array) -> String:
 return Importer.apply_configuration(config)

static func refresh_app(app):
 app.textures.clear();app.load_error=""
 app.draft=app.Store.migrate_unavailable_cards(app.draft)
 if app.Store.unavailable_card(app.selected):app.selected=""
 app.reload_decks()
 if is_instance_valid(app.lan_session):app.lan_session.refresh_rules()

static func room_guard(app) -> bool:
 if not is_instance_valid(app.lan_session) or app.lan_session.room_id.is_empty():return false
 var status=app.screen.find_child("ModStatus",true,false)
 if status!=null:status.text="请先退出当前房间，再更改模组。"
 return true

static func request_back(app):
 if app.page!="mods":return
 var config=app.screen.get_meta("ModDraft",[])
 if config==Registry.configuration():app.settings();return
 if app.find_child("ModUnsavedChanges",false,false)!=null:return
 var dialog=ConfirmationDialog.new();dialog.name="ModUnsavedChanges";dialog.title="保存模组选择"
 dialog.dialog_text="模组加载选择已变化，是否保存？";dialog.get_ok_button().text="保存";dialog.get_cancel_button().text="取消"
 var discard=dialog.add_button("不保存",true,"discard");discard.name="DiscardModChanges"
 dialog.confirmed.connect(func():
  dialog.queue_free()
  if app.page!="mods" or room_guard(app):return
  var error=apply_configuration(app.screen.get_meta("ModDraft",[]))
  if not error.is_empty():app.screen.find_child("ModStatus",true,false).text=error;return
  refresh_app(app);app.settings())
 dialog.custom_action.connect(func(action):
  if action=="discard":
   dialog.queue_free()
   if app.page=="mods":app.settings())
 dialog.canceled.connect(dialog.queue_free)
 app.add_child(dialog);app.style_dialog(dialog)
 if app.is_android:app.ui_metrics.button(discard);discard.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
 dialog.popup_centered()

static func request_delete(app,path: String,title: String):
 if room_guard(app):return
 app.confirm_action("删除模组「%s」？\n%s" % [title,"本地安装文件将被删除。" if Importer.managed_path(path) else "将移除模组登记，原目录文件保留。"],func():
  if app.page!="mods" or room_guard(app):return
  var result=Importer.delete_mod(path,Registry.configuration())
  if result.has("error"):app.screen.find_child("ModStatus",true,false).text=result.error;return
  refresh_app(app)
  show(app,"已删除："+title+("。" if result.removed_files else "（原目录文件保留）。")))

static func show(app,notice: String=""):
 # Rebuilding after a resize, import or deletion must retain unapplied choices.
 var selection=app.screen.get_meta("ModDraft",[]) if app.page=="mods" and is_instance_valid(app.screen) else []
 var config=Registry.configuration()
 for item in config:
  for old in selection:
   if Importer.normalized_path(str(old.get("path","")))==Importer.normalized_path(str(item.get("path",""))):item.enabled=old.get("enabled",false);break
 app.clear_page("mods")
 app.screen.set_meta("ModDraft",config)
 var layout=preload("res://scripts/menu_ui_layout.gd").new()
 var root=layout.page(app,"模组",func():request_back(app))
 wrapped_text(layout,root,"导入可信的 ZIP 模组文件；相同 ID 的新版将自动替换并保留启用状态，同版或旧版不覆盖。勾选后应用，组卡和建房时选择「模组」规则集。")
 wrapped_text(layout,root,"模组文件夹："+Registry.install_root())
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(scroll);layout.expand(scroll,true)
 var list=VBoxContainer.new();scroll.add_child(list);layout.expand(list)
 if config.is_empty():wrapped_text(layout,list,"尚未导入模组。请选择包含 manifest.json、脚本和卡牌资源的 ZIP 文件。")
 for item in config:
  var path=str(item.get("path",""));var manifest={}
  if FileAccess.file_exists(path.path_join("manifest.json")):
   var data=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("manifest.json")))
   if data is Dictionary:manifest=data
  var entry=HBoxContainer.new();list.add_child(entry)
  var check=CheckButton.new();check.name="Mod_"+str(manifest.get("id","missing"));entry.add_child(check)
  check.clip_text=true;layout.expand(check)
  check.text=str(manifest.get("name",manifest.get("id","找不到模组")))+"  "+str(manifest.get("version",""));check.button_pressed=item.get("enabled",false)
  check.toggled.connect(func(value):item.enabled=value)
  var title=str(manifest.get("name",manifest.get("id","找不到模组")))
  layout.action(entry,"删除",func():request_delete(app,path,title)).name="DeleteMod_"+str(manifest.get("id","missing"))
  wrapped_text(layout,list,path)
 var status=wrapped_text(layout,root,notice if not notice.is_empty() else "已启用："+", ".join(Registry.shared().packs.keys()));status.name="ModStatus"
 var row=HBoxContainer.new();root.add_child(row)
 layout.action(row,"导入模组文件…",func():
  if room_guard(app):return
  var picker=create_picker(app)
  picker.popup_centered_ratio(0.8)).name="ImportModFile"
 layout.action(row,"应用选择",func():
  if room_guard(app):return
  var error=apply_configuration(config)
  if not error.is_empty():status.text=error;return
  refresh_app(app);status.text="已应用："+", ".join(Registry.shared().packs.keys()))

static func wrapped_text(layout,parent: Node,value: String) -> Label:
 var label=layout.text(parent,value);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 layout.expand(label)
 return label

static func create_picker(app) -> FileDialog:
 var picker=FileDialog.new();picker.name="ModFilePicker";picker.title="导入模组文件"
 picker.access=FileDialog.ACCESS_FILESYSTEM;picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE;picker.use_native_dialog=true
 picker.filters=PackedStringArray(["*.zip ; ZIP 模组文件"])
 app.add_child(picker)
 picker.file_selected.connect(func(path):
  picker.queue_free()
  if app.page!="mods":return
  var status=app.screen.find_child("ModStatus",true,false)
  if room_guard(app):return
  var result=Importer.import_file(path,Registry.configuration())
  if result.has("error"):status.text=result.error;return
  if result.updated:
   for item in app.screen.get_meta("ModDraft",[]):
    if Importer.normalized_path(str(item.get("path","")))==Importer.normalized_path(result.previous_path):item.path=result.path
  refresh_app(app)
  show(app,("已更新：%s（%s → %s），已保留启用状态。" % [result.name,result.previous_version,result.version]) if result.updated else "已导入："+result.name+"。勾选后点击「应用选择」启用。"))
 picker.canceled.connect(picker.queue_free)
 return picker
