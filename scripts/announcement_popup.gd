extends "res://scripts/modal_menu.gd"
## Archive and release reader share the existing modal input and swipe handling.
var entries: VBoxContainer
var selected_version=""
var selected_id=""
var automatic=false
var archive_button: Button
var reader_row: HBoxContainer
var announcement_image: TextureRect

func build_announcements(app,entry: Dictionary={},push: bool=false):
 super.build(app,"公告邮箱",[])
 name="AnnouncementPopup";panel.name="AnnouncementPanel";scroll.name="AnnouncementScroll"
 entries=scroll.get_child(0)
 heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var header=close_button.get_parent()
 archive_button=host.button(header,"邮箱",Rect2(),show_archive)
 archive_button.name="AnnouncementBack";archive_button.tooltip_text="返回公告邮箱"
 host.ui_metrics.button(archive_button);header.move_child(archive_button,close_button.get_index())
 automatic=push
 if entry.is_empty():show_archive()
 else:show_entry(entry)
 relayout()

func clear_entries():
 if is_instance_valid(reader_row):
  scroll.reparent(body)
  body.remove_child(reader_row);reader_row.queue_free();reader_row=null
 announcement_image=null
 for child in entries.get_children():entries.remove_child(child);child.queue_free()
 scroll.scroll_vertical=0

func text(value: String,font: int,color: Color,node_name: String="") -> Label:
 var label=Label.new();entries.add_child(label);label.text=value
 if not node_name.is_empty():label.name=node_name
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label.add_theme_font_size_override("font_size",font)
 label.add_theme_color_override("font_color",color)
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 return label

func show_archive():
 clear_entries();selected_version="";selected_id="";heading.text="公告邮箱";close_button.text="关闭"
 archive_button.hide();host.ui_metrics.button(close_button)
 var store=host.announcement_store
 text("共 %d 条公告 · %d 条未读" % [store.history.size(),store.unread_count()],host.ui_metrics.small,host.MUTED)
 if store.history.is_empty():text("暂无公告",host.ui_metrics.body,host.WHITE)
 for entry in store.history:
  var id=store.entry_id(entry)
  var caption=("未读 · " if id not in store.read_versions else "")+str(entry.title)
  var action=host.button(entries,caption,Rect2(),func():automatic=false;show_entry(entry))
  action.name="Announcement_"+id.replace(".","_").replace(":","_")
  action.set_meta("announcement_version",entry.version)
  action.set_meta("announcement_id",id)
  host.ui_metrics.button(action);action.custom_minimum_size.x=0
  action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  text("%s · 版本 %s" % [entry.get("date",""),entry.version],host.ui_metrics.small,host.MUTED)
 relayout();connect_focus();close_button.grab_focus()

func show_entry(entry: Dictionary):
 clear_entries();selected_version=entry.version;selected_id=host.announcement_store.entry_id(entry);heading.text="更新公告"
 close_button.text="知道了" if automatic else "关闭"
 archive_button.show();host.ui_metrics.button(close_button)
 text(entry.title,maxi(24,host.ui_metrics.title),host.GOLD,"AnnouncementTitle")
 text("%s · 版本 %s" % [entry.get("date",""),entry.version],host.ui_metrics.small,host.MUTED,"AnnouncementVersion")
 text(entry.body,maxi(24,host.ui_metrics.body),host.WHITE,"AnnouncementBody")
 show_image(entry)
 if not host.announcement_store.record_opened(selected_id,automatic):push_warning(host.announcement_store.last_error)
 host.refresh_mailbox_badge()
 relayout();connect_focus();close_button.grab_focus()

func show_image(entry: Dictionary):
 var path=entry.get("image","")
 if not path is String or path.is_empty():return
 var texture: Texture2D
 if ResourceLoader.exists(path,"Texture2D"):texture=load(path) as Texture2D
 # Direct PC launches can precede the editor's image import pass.
 if texture==null and FileAccess.file_exists(path):
  var original=Image.load_from_file(path)
  if original!=null and not original.is_empty():texture=ImageTexture.create_from_image(original)
 if texture==null:
  text("群聊配图暂未加载，请使用公告中的群号加入群聊。",host.ui_metrics.small,host.MUTED)
  return
 var region=entry.get("image_region",[])
 if region is Array and region.size()==4:
  var cropped=AtlasTexture.new();cropped.atlas=texture
  cropped.region=Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
  cropped.filter_clip=true;texture=cropped
 var parent: Node=entries
 if not host.is_android:
  reader_row=HBoxContainer.new();reader_row.name="AnnouncementReader";body.add_child(reader_row)
  reader_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  reader_row.size_flags_vertical=Control.SIZE_EXPAND_FILL
  reader_row.add_theme_constant_override("separation",int(host.ui_metrics.gap*2))
  scroll.reparent(reader_row);scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  parent=reader_row
 var image=TextureRect.new();image.name="AnnouncementImage";parent.add_child(image)
 announcement_image=image
 image.texture=texture;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 if host.is_android:
  image.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  image.custom_minimum_size.y=minf(560,maxf(360,host.ui_metrics.safe.size.y*0.65))
 else:
  image.size_flags_vertical=Control.SIZE_EXPAND_FILL
  image.custom_minimum_size.x=400
 image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 image.tooltip_text="群头像、群名、群号与入群二维码"

func connect_focus():
 var buttons: Array[Button]=[close_button]
 if archive_button.visible:buttons.append(archive_button)
 for child in entries.get_children():
  if child is Button:buttons.append(child)
 for i in range(buttons.size()):
  var control=buttons[i]
  var previous=control.get_path_to(buttons[(i-1+buttons.size())%buttons.size()])
  var next=control.get_path_to(buttons[(i+1)%buttons.size()])
  control.focus_previous=previous;control.focus_next=next
  control.focus_neighbor_top=previous;control.focus_neighbor_bottom=next
  control.focus_neighbor_left=previous;control.focus_neighbor_right=next

func relayout():
 if not is_instance_valid(panel):return
 var safe=host.ui_metrics.safe
 var desktop_image=not host.is_android and is_instance_valid(reader_row)
 var extent=Vector2(minf(1280 if host.is_android else 1160 if desktop_image else 920,safe.size.x),minf(760 if desktop_image else 620,safe.size.y))
 if desktop_image and is_instance_valid(announcement_image):announcement_image.custom_minimum_size.x=minf(420,extent.x*0.36)
 panel.size=extent;panel.position=safe.position+(safe.size-extent)*0.5
