extends RefCounted
const Library=preload("res://scripts/replay_library.gd")

static func show(app):
 app.header("对局回放",app.menu)
 var error=Library.initialize()
 var history=app.replay_history_tab
 var files=Library.entries(history) if error.is_empty() else []
 var m=app.ui_metrics
 var margin=m.padding if app.is_android else 80.0
 var top=m.hit+m.gap*3+m.title+margin if app.is_android else 151.0
 var width=app.screen.size.x-margin*2 if app.is_android else 1440.0
 var tabs=HBoxContainer.new();tabs.name="ReplayTabs";app.screen.add_child(tabs)
 tabs.position=Vector2(margin,top);tabs.size.x=width;tabs.add_theme_constant_override("separation",int(m.gap))
 for item in [["最近历史",true],["已保留",false]]:
  var selected=bool(item[1])
  var button=app.button(tabs,item[0],Rect2(),func():app.replay_history_tab=selected;app.replays(),history==selected)
  button.toggle_mode=true;button.button_pressed=history==selected
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.custom_minimum_size.y=m.hit if app.is_android else 48
  if app.is_android:m.button(button)
 var caption="最近 %d / %d 场 · 超过上限时自动删除最早录像，保留后可长期查看。" % [files.size(),Library.HISTORY_LIMIT] if history else "已保留 %d 场 · 可长期保存、播放或导出。" % files.size()
 if not error.is_empty():caption=error
 var notice=app.label(app.screen,caption,Rect2(margin,top+(m.hit if app.is_android else 48)+m.gap,width,m.body*2.6),18,app.MUTED)
 notice.name="ReplayNotice";notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var scroll=ScrollContainer.new();scroll.name="ReplayScroll";app.screen.add_child(scroll)
 scroll.position=Vector2(margin,notice.position.y+notice.size.y+m.gap)
 scroll.size=Vector2(width,maxf(m.hit,app.screen.size.y-scroll.position.y-margin))
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",int(m.gap));scroll.add_child(list)
 for entry in files:
  var row=HBoxContainer.new();row.name="ReplayRow";list.add_child(row);row.add_theme_constant_override("separation",int(m.gap))
  var path=str(entry.path)
  var play=app.button(row,entry.caption,Rect2(),func():open(app,path))
  play.name="ReplayPlay";play.alignment=HORIZONTAL_ALIGNMENT_LEFT;play.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  play.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;play.tooltip_text=entry.caption
  play.custom_minimum_size=Vector2(0,m.hit if app.is_android else 64)
  if app.is_android:m.button(play);play.custom_minimum_size.x=0
  if history:
   var saved=FileAccess.file_exists(Library.folder().path_join(entry.filename))
   var keep_button=app.button(row,"已保留" if saved else "保留",Rect2(),func():
    var result=Library.keep(path)
    if result.has("error"):app.alert(result.error,"保留录像失败")
    else:app.replays())
   keep_button.name="ReplayKeep";keep_button.disabled=saved
   if app.is_android:m.button(keep_button)
   else:keep_button.custom_minimum_size.x=110
  var export_button=app.button(row,"导出",Rect2(),func():export_dialog(app,path))
  export_button.name="ReplayExport"
  if app.is_android:m.button(export_button)
  else:export_button.custom_minimum_size.x=110
 if files.is_empty():
  var empty=Label.new();empty.text="暂无历史录像，对局结束后会自动记录。" if history else "暂无已保留录像，可在最近历史中选择保留。"
  empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;list.add_child(empty)
  if app.is_android:empty.add_theme_font_size_override("font_size",m.body)

static func open(app,path: String):
 app.open_replay(path)

static func export_dialog(app,path: String) -> FileDialog:
 var picker=FileDialog.new();picker.name="ReplayExportPicker";picker.title="导出录像"
 picker.access=FileDialog.ACCESS_FILESYSTEM;picker.file_mode=FileDialog.FILE_MODE_SAVE_FILE;picker.use_native_dialog=true
 picker.filters=PackedStringArray(["*.mreply ; 对局录像"])
 picker.current_file=path.get_file()
 app.add_child(picker)
 picker.file_selected.connect(func(destination):
  picker.hide();picker.queue_free()
  var result=Library.export_file(path,destination)
  if result.has("error"):app.alert(result.error,"导出录像失败")
  else:app.alert("已导出至：\n"+result.path,"录像已导出"))
 picker.canceled.connect(picker.queue_free)
 picker.popup_centered(Vector2i(1000,650))
 return picker
