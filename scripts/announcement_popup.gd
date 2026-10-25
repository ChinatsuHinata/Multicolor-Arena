extends "res://scripts/modal_menu.gd"
## Archive and release reader share the existing modal input and swipe handling.
var entries: VBoxContainer
var selected_version=""
var selected_id=""
var automatic=false
var archive_button: Button
var reader_row: HBoxContainer
var announcement_image: TextureRect
var archive_row: HBoxContainer
var read_tabs: Array[Button]=[]
var showing_read=false
var claim_busy=false
var claim_button: Button
var claim_notice: Label
var claim_message=""
var claim_message_id=""

func build_announcements(app,entry: Dictionary={},push: bool=false):
 app.announcement_store.set_account(app.account_name if not app.account_token.is_empty() else "")
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
 host.online_community().request({"action":"announcements"},func(answer):
  if not is_instance_valid(self) or not answer.get("ok",false):return
  var incoming=answer.get("announcements",[])
  host.announcement_store.merge_online(incoming);host.refresh_mailbox_badge()
  refresh_announcements())

func refresh_announcements():
 if selected_id.is_empty():show_archive()
 else:update_claim_controls()

func clear_entries():
 claim_button=null;claim_notice=null
 if is_instance_valid(reader_row):
  scroll.reparent(body)
  body.remove_child(reader_row);reader_row.queue_free();reader_row=null
 announcement_image=null
 if is_instance_valid(archive_row):
  scroll.reparent(body)
  body.remove_child(archive_row);archive_row.queue_free();archive_row=null
 read_tabs.clear()
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
 archive_row=HBoxContainer.new();archive_row.name="MailboxPanes";body.add_child(archive_row)
 archive_row.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var sidebar=VBoxContainer.new();sidebar.name="MailboxTabs";archive_row.add_child(sidebar)
 for index in range(2):
  var count=store.history.size()-store.unread_count() if index==1 else store.unread_count()
  var tab=host.button(sidebar,("已读" if index==1 else "未读")+"（%d）" % count,Rect2(),select_read_tab.bind(index==1))
  tab.name="ReadAnnouncements" if index==1 else "UnreadAnnouncements"
  tab.toggle_mode=true;tab.button_pressed=showing_read==(index==1)
  host.ui_metrics.button(tab);read_tabs.append(tab)
 scroll.reparent(archive_row);scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var visible_entries=store.history.filter(func(entry):return store.is_read(entry)==showing_read)
 text("共 %d 条%s公告" % [visible_entries.size(),"已读" if showing_read else "未读"],host.ui_metrics.small,host.MUTED)
 if visible_entries.is_empty():text("暂无已读公告" if showing_read else "暂无未读公告",host.ui_metrics.body,host.WHITE)
 for entry in visible_entries:
  var id=store.entry_id(entry)
  var caption=str(entry.title)
  var action=host.button(entries,caption,Rect2(),func():automatic=false;show_entry(entry))
  action.name="Announcement_"+id.replace(".","_").replace(":","_")
  action.set_meta("announcement_version",entry.version)
  action.set_meta("announcement_id",id)
  host.ui_metrics.button(action);action.custom_minimum_size.x=0
  action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  if store.needs_attention(entry):
   action.set_meta("has_red_dot",true)
   action.draw.connect(func():action.draw_circle(Vector2(action.size.x-12,12),5,Color("#f16d69"),true,-1,true))
  text("%s · 版本 %s" % [entry.get("date",""),entry.version],host.ui_metrics.small,host.MUTED)
 relayout();connect_focus();close_button.grab_focus()

func select_read_tab(read: bool):
 showing_read=read;show_archive()

func show_entry(entry: Dictionary):
 clear_entries();selected_version=entry.version;selected_id=host.announcement_store.entry_id(entry);heading.text="更新公告"
 close_button.text="知道了" if automatic else "关闭"
 archive_button.show();host.ui_metrics.button(close_button)
 text(entry.title,maxi(24,host.ui_metrics.title),host.GOLD,"AnnouncementTitle")
 text("%s · 版本 %s" % [entry.get("date",""),entry.version],host.ui_metrics.small,host.MUTED,"AnnouncementVersion")
 text(entry.body,maxi(24,host.ui_metrics.body),host.WHITE,"AnnouncementBody")
 var coins=int(entry.get("coins",0))
 if coins>0:
  claim_notice=text("",host.ui_metrics.small,host.GOLD,"AnnouncementClaimStatus")
  claim_notice.custom_minimum_size.y=host.ui_metrics.small*1.5
  claim_button=host.button(entries,"",Rect2(),func():claim_coins(selected_id))
  claim_button.name="ClaimAnnouncementCoins";host.ui_metrics.button(claim_button)
  update_claim_controls()
 show_image(entry)
 if not host.announcement_store.record_opened(selected_id,automatic):push_warning(host.announcement_store.last_error)
 host.refresh_mailbox_badge()
 relayout();connect_focus();close_button.grab_focus()

func claim_coins(id: String):
 if claim_busy or host.announcement_store.is_claimed(id):return
 claim_message_id=id
 if host.account_token.is_empty():
  claim_message="请先登录玩家账号，再回来领取公告铜钱。";update_claim_controls();return
 claim_busy=true;claim_message="正在领取…";update_claim_controls()
 host.claim_announcement_coins(id,func(answer):
  if not is_instance_valid(self):return
  claim_busy=false
  claim_message_id=id;claim_message=str(answer.get("message","领取失败"))
  update_claim_controls())

func update_claim_controls():
 if not is_instance_valid(claim_button):return
 var coins=int(host.announcement_store.find_id(selected_id).get("coins",0))
 var claimed=host.announcement_store.is_claimed(selected_id)
 claim_button.text="已领取 %d 铜钱" % coins if claimed else "领取 %d 铜钱" % coins
 claim_button.disabled=claimed or claim_busy
 # Keep reward feedback beside the claim button without interrupting reading.
 claim_notice.text=claim_message if claim_message_id==selected_id else ""

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
 buttons.append_array(read_tabs)
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
