extends Control
const Series=preload("res://net/series_controller.gd")
var app
var session
var body: Control
var back_button: Button
var header_mode_button: Button
var status_label: Label
var latency_label: Label
var name_input: LineEdit
var address_input: LineEdit
var mode_selected=false
var cloud_selected=false
var cloud_directory
var cloud_title_input: LineEdit
var cloud_password_input: LineEdit
var cloud_host_slot: OptionButton
var cloud_rooms_list: VBoxContainer
var matchmaking_label: Label
var cloud_room_columns=4
const DEFAULT_RELAY_SERVER="ws://8.137.122.187:47862"
var port_input: SpinBox
var format_input: OptionButton
var rule_input: OptionButton
var interface_input: OptionButton
var strict_input: CheckButton
var rooms_list: VBoxContainer
var signature=""
var deck_index=0
var last_error=""

func add_formats():
 format_input.name="MatchFormat"
 format_input.add_item("BO3 · 先赢两局",Series.BO3)
 format_input.add_item("BO1 · 单局",Series.BO1)
 format_input.add_item("BO1 换备牌",Series.BO1_SIDEBOARD)

func preparation_hint(room: Dictionary) -> String:
 if room.status=="sideboarding":return "赛前换备牌：最多换入 3 张；双方准备后投骰选择先后手"
 if room.status=="lobby":
  return "双方准备后公开自机，进入赛前换备牌" if int(room.format)==Series.BO1_SIDEBOARD else "双方准备后投骰，点数高者选择先后手"
 return "双方准备后由上一局败者选择先后手" if room.last_winner in [0,1] else "双方准备后由上一局选择者选择先后手"

func leader_reveal(room: Dictionary) -> String:
 var leaders=room.get("leaders",[])
 if leaders.size()!=2:return ""
 if not session.read_only:
  return "对方自机："+str(app.Store.CARDS.get(leaders[1-session.seat],{}).get("name","未知自机"))
 return "自机：%s / %s" % [app.Store.CARDS.get(leaders[0],{}).get("name","未知自机"),app.Store.CARDS.get(leaders[1],{}).get("name","未知自机")]

func deck_choice_button(parent: Node,rect: Rect2=Rect2()) -> Button:
 deck_index=clampi(deck_index,0,maxi(0,app.decks.size()-1))
 var button=app.button(parent,app.deck_choice_caption(deck_index),rect,func():
  var current_id=str(app.decks[deck_index].id) if not app.decks.is_empty() else ""
  app.open_deck_picker(select_deck,current_id,"选择联机套牌"))
 button.name="NetworkDeckSelect";button.disabled=not session.can_act()
 button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 if rect==Rect2():
  app.ui_metrics.button(button);button.custom_minimum_size.x=0
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 return button

func select_deck(index: int):
 if not session.can_act():show_error("等待双方连接或同步完成");return
 if session.room.get("status","")!="lobby":show_error("当前不能更换整套卡组");return
 if index<0 or index>=app.decks.size():return
 var deck=app.Store.clean_deck(app.decks[index])
 var error=app.Store.validate(deck,session.room.get("strict",true),str(session.room.get("rule_set",app.RuleSet.UNRESTRICTED)))
 if not error.is_empty():show_error(error);return
 deck_index=index;last_error=""
 session.room_action({"name":"deck","deck":deck})
 refresh(true)

func register_deck_button(parent: Node,rect: Rect2=Rect2()) -> Button:
 var callback=func():select_deck(deck_index)
 var button=mobile_action(parent,"选择此卡组",callback) if rect==Rect2() else app.button(parent,"选择此卡组",rect,callback)
 button.disabled=not session.can_act() or app.decks.is_empty()
 return button

func build(parent,net):
 app=parent;session=net;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 if not session.room_id.is_empty() or session.joining or session.matchmaking:
  mode_selected=true;cloud_selected=session.cloud_mode
 cloud_directory=preload("res://net/cloud_directory.gd").new();add_child(cloud_directory)
 cloud_directory.changed.connect(refresh_cloud_rooms)
 cloud_directory.failed.connect(show_error)
 session.changed.connect(refresh);session.error_raised.connect(show_error)
 back_button=app.header("联机对战",func():
  if session.disconnected_at>0:session.stop_waiting()
  else:session.leave(false)
  app.menu(),header_cloud_size().x+app.ui_metrics.gap)
 status_label=app.label(self,"",Rect2(0,116,app.screen.size.x,66) if app.is_android else Rect2(70,118,1460,65),20,app.GOLD);status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 body=Control.new();add_child(body)
 if app.is_android:
  body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  body.offset_top=185
 refresh(true)
func show_error(message: String):
 last_error=message;status_label.text=message
 app.alert(message,"无法进行联机操作")
func _process(_delta):
 if is_instance_valid(matchmaking_label):matchmaking_label.text=session.notice
 if is_instance_valid(latency_label):latency_label.text="网络延迟 · "+session.latency_text()
 if session.disconnected_at>0 or session.ended():status_label.text=session.connection_status()
func refresh(force: bool=false):
 status_label.text=last_error if not last_error.is_empty() else session.notice if not session.notice.is_empty() else session.discovery.error
 var next=JSON.stringify([session.room_id,session.room,session.applicant,session.connected,session.paused,session.busy,session.wait_choice_pending,session.wait_choice_confirmed,session.cloud_seats,session.cloud_slot,session.read_only,mode_selected,cloud_selected,session.cloud_mode,session.matchmaking,session.cloud_ranked,session.match_settled])
 if force or next!=signature:
  signature=next
  rooms_list=null;cloud_rooms_list=null;latency_label=null;matchmaking_label=null
  for child in body.get_children():body.remove_child(child);child.queue_free()
  if not app.is_android:
   body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
   body.offset_top=185 if not mode_selected or cloud_selected or session.cloud_mode else 0
  if session.room_id.is_empty():
   if session.matchmaking or session.cloud_ranked and session.joining:build_matchmaking_wait()
   elif not mode_selected:build_mode_selection()
   elif cloud_selected:build_cloud_home()
   elif app.is_android:build_mobile_home()
   else:build_home()
  elif session.cloud_mode and session.room.get("status","")=="lobby":build_cloud_room_lobby()
  elif app.is_android or session.cloud_mode:build_responsive_room()
  else:build_room()
  refresh_header_mode_button()
 refresh_rooms()
 refresh_cloud_rooms()

func set_cloud_mode(enabled: bool):
 if enabled and app.cloud_match_blocked():
  app.explain_cloud_match_block();return
 if enabled and app.account_token.is_empty():
  app.alert("请先在主菜单的玩家账号中登录，再进入云端。","需要登录");refresh(true);return
 mode_selected=true;cloud_selected=enabled;last_error=""
 session.cloud_token=app.account_token;session.cloud_nickname=app.account_nickname
 if enabled:cloud_directory.start(DEFAULT_RELAY_SERVER,app.account_token)
 else:cloud_directory.stop()
 refresh(true)

func build_mode_selection():
 var root=mobile_scroll();root.name="OnlineModeSelection"
 root.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var center=CenterContainer.new();root.add_child(center)
 center.size_flags_horizontal=Control.SIZE_EXPAND_FILL;center.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var content=VBoxContainer.new();center.add_child(content)
 content.add_theme_constant_override("separation",int(app.ui_metrics.gap*2))
 var heading=mobile_text(content,"选择联机方式",true);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var choices=HBoxContainer.new() if body.size.x>=640 else VBoxContainer.new();content.add_child(choices)
 choices.add_theme_constant_override("separation",int(app.ui_metrics.gap*2))
 var cloud=mobile_action(choices,"云端",func():set_cloud_mode(true),true);cloud.name="ChooseCloudMode"
 var lan=mobile_action(choices,"局域网",func():set_cloud_mode(false));lan.name="ChooseLanMode"
 for button in [cloud,lan]:
  button.custom_minimum_size=Vector2(minf(280,body.size.x-app.ui_metrics.padding*2),maxf(112,app.ui_metrics.hit*1.5))
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.add_theme_font_size_override("font_size",app.ui_metrics.title)
 var note=mobile_text(content,"云端可跨网络对战；局域网可连接同一网络内的玩家。")
 note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func header_cloud_size() -> Vector2:
 var height=maxf(100,app.ui_metrics.hit)
 return Vector2(height*2.2,height)

func refresh_header_mode_button():
 if is_instance_valid(header_mode_button):
  remove_child(header_mode_button);header_mode_button.queue_free();header_mode_button=null
 if not mode_selected or not session.room_id.is_empty() or session.matchmaking:return
 var gap=app.ui_metrics.gap
 if cloud_selected:
  var width=maxf(back_button.size.x,app.ui_metrics.body*3+app.ui_metrics.padding*2)
  var rect=Rect2(back_button.position-Vector2(width+gap,0),Vector2(width,back_button.size.y))
  header_mode_button=app.button(self,"局域网",rect,func():set_cloud_mode(false))
  header_mode_button.name="LanModeButton"
 else:
  var extent=header_cloud_size()
  var origin=Vector2(back_button.position.x-extent.x-gap,maxf(0,back_button.position.y+(back_button.size.y-extent.y)*0.5))
  header_mode_button=cloud_entry(self,Rect2(origin,extent))

func cloud_entry(parent: Node,rect: Rect2) -> Button:
 var button=preload("res://net/cloud_mode_button.gd").new();button.name="CloudModeButton"
 button.add_theme_font_size_override("font_size",maxi(30,app.ui_metrics.title))
 button.position=rect.position;button.custom_minimum_size=rect.size;button.size=rect.size
 button.pressed.connect(func():set_cloud_mode(true))
 parent.add_child(button)
 return button
func input(text: String,rect: Rect2) -> LineEdit:
 var edit=LineEdit.new();edit.position=rect.position;edit.size=rect.size;edit.text=text;body.add_child(edit);return edit
func build_home():
 app.box(body,Rect2(70,190,500,620));app.box(body,Rect2(600,190,930,620))
 app.label(body,"显示 ID",Rect2(100,210,120,35),21)
 name_input=input(session.identity.nickname,Rect2(230,208,302,44));name_input.max_length=20
 app.label(body,"对局形式",Rect2(100,280,120,40),21)
 format_input=OptionButton.new();format_input.position=Vector2(230,279);format_input.size=Vector2(302,43);add_formats();body.add_child(format_input)
 app.label(body,"规则集",Rect2(100,341,120,40),21)
 rule_input=OptionButton.new();rule_input.name="RoomRuleSet";rule_input.position=Vector2(230,339);rule_input.size=Vector2(302,43)
 rule_input.tooltip_text="规则集由房主决定，双方登记卡组和换备牌都必须符合该规则。"
 for rule_name in app.RuleSet.LABELS:rule_input.add_item(rule_name)
 body.add_child(rule_input)
 strict_input=CheckButton.new();strict_input.text="主卡组必须 50 张";strict_input.position=Vector2(95,389);strict_input.size=Vector2(440,45);strict_input.button_pressed=true;body.add_child(strict_input)
 app.label(body,"端口",Rect2(100,448,120,42),21)
 port_input=SpinBox.new();port_input.min_value=1024;port_input.max_value=65534;port_input.value=47861;port_input.position=Vector2(230,447);port_input.size=Vector2(302,42);body.add_child(port_input)
 interface_input=OptionButton.new();interface_input.position=Vector2(100,501);interface_input.size=Vector2(432,43);interface_input.add_item("所有网卡");interface_input.set_item_metadata(0,"*")
 for address in IP.get_local_addresses():
  if address.is_valid_ip_address() and ":" not in address and not address.begins_with("127."):
   interface_input.add_item(address);interface_input.set_item_metadata(interface_input.item_count-1,address)
 body.add_child(interface_input)
 app.button(body,"创建房间",Rect2(100,560,432,54),func():
  session.set_display_name(name_input.text)
  var error=session.create_room(format_input.get_selected_id(),strict_input.button_pressed,int(port_input.value),interface_input.get_selected_metadata(),app.RuleSet.IDS[rule_input.selected])
  if not error.is_empty():show_error(error),true)
 app.button(body,"恢复房主对局",Rect2(100,626,432,49),func():
  var error=session.restore_host()
  if not error.is_empty():show_error(error))
 app.button(body,"重连上次房间",Rect2(100,693,432,49),func():
  session.set_display_name(name_input.text)
  var error=session.resume_guest(address_input.text)
  if not error.is_empty():show_error(error))
 app.label(body,"发现的房间",Rect2(625,208,500,43),25,app.GOLD)
 var scroll=ScrollContainer.new();scroll.position=Vector2(625,264);scroll.size=Vector2(877,194);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
 rooms_list=VBoxContainer.new();rooms_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rooms_list.add_theme_constant_override("separation",12);scroll.add_child(rooms_list)
 app.label(body,"输入地址加入",Rect2(625,638,210,40),21)
 address_input=input("",Rect2(625,690,620,49));address_input.placeholder_text="房主 IP、域名或 地址:UDP端口"
 app.button(body,"加入",Rect2(1265,690,108,49),func():join(address_input.text,int(port_input.value)),true)
 app.button(body,"观战",Rect2(1383,690,117,49),func():watch(address_input.text,int(port_input.value)))
 app.label(body,"点击返回按钮旁的云朵进入云端联机。",Rect2(625,753,855,38),17,app.MUTED)
func join(address: String,port: int):
 session.set_display_name(name_input.text)
 var error=session.join_room(address,port)
 if not error.is_empty():show_error(error)
func create_relay():
 if app.cloud_match_blocked():app.explain_cloud_match_block();return
 last_error=""
 var error=session.create_relay_room(DEFAULT_RELAY_SERVER,format_input.get_selected_id(),strict_input.button_pressed,app.RuleSet.IDS[rule_input.selected],cloud_title_input.text,cloud_password_input.text,cloud_host_slot.selected+1)
 if not error.is_empty():show_error(error)

func start_matchmaking():
 if app.cloud_match_blocked():app.explain_cloud_match_block();return
 last_error=""
 session.cloud_token=app.account_token;session.cloud_nickname=app.account_nickname
 var error=session.start_matchmaking(DEFAULT_RELAY_SERVER)
 if not error.is_empty():show_error(error)

func build_matchmaking_wait():
 var root=mobile_scroll();var panel=mobile_panel(root)
 mobile_text(panel,"自动匹配 · BO1 换备牌",true)
 var rules=mobile_text(panel,"规则集固定为"+app.RuleSet.label_for(session.MATCH_RULE_SET)+" · 主卡组 50 张");rules.name="MatchmakingRules"
 matchmaking_label=mobile_text(panel,session.notice);matchmaking_label.name="MatchmakingStatus"
 mobile_text(panel,"优先匹配 Elo 相近的玩家；等待满 1 分钟后，每分钟扩大 100 分范围。")
 var cancel=mobile_action(panel,"取消匹配",func():session.cancel_matchmaking();refresh(true))
 cancel.name="CancelMatchmaking";cancel.disabled=not session.matchmaking

func join_cloud_room(info: Dictionary,slot: int,password: String=""):
 if app.cloud_match_blocked():app.explain_cloud_match_block();return
 last_error=""
 var error=session.join_relay_room(DEFAULT_RELAY_SERVER,str(info.id),false,slot,password)
 if not error.is_empty():show_error(error)

func choose_cloud_room_seat(info: Dictionary,slot: int):
 if app.cloud_match_blocked():app.explain_cloud_match_block();return
 if info.get("watch_only",false) and slot<=2:return
 if not info.get("locked",false):
  join_cloud_room(info,slot)
  return
 var dialog=ConfirmationDialog.new()
 dialog.title="加入加密房间"
 var seat_label="自动分配观战位" if str(info.get("status","lobby"))!="lobby" else "%d 号%s位" % [slot,"对战" if slot<=2 else "观战"]
 dialog.min_size=Vector2i(540,185)
 dialog.get_ok_button().text="加入房间"
 dialog.get_cancel_button().text="取消"
 dialog.get_label().hide()
 var content=VBoxContainer.new()
 content.add_theme_constant_override("separation",12)
 dialog.add_child(content)
 var description=Label.new()
 description.text="%s · %s\n请输入房间密码" % [str(info.get("name","房间")),seat_label]
 content.add_child(description)
 var password_input=preload("res://scripts/password_edit.gd").new()
 password_input.name="CloudJoinPassword"
 password_input.secret=true
 password_input.max_length=32
 password_input.placeholder_text="房间密码"
 password_input.custom_minimum_size.y=48
 content.add_child(password_input)
 dialog.confirmed.connect(func():
  var password=password_input.text
  dialog.queue_free()
  if password.is_empty():show_error("请输入房间密码")
  else:join_cloud_room(info,slot,password))
 dialog.canceled.connect(dialog.queue_free)
 add_child(dialog)
 app.style_dialog(dialog)
 dialog.popup_centered()
 password_input.grab_focus()

func build_cloud_home():
 var root=mobile_scroll()
 mobile_text(root,"云端房间 · "+app.account_nickname,true)
 var matching=mobile_panel(root)
 mobile_text(matching,"自动匹配 · BO1 换备牌",true)
 var rules=mobile_text(matching,"主卡组 50 张 · "+app.RuleSet.label_for(session.MATCH_RULE_SET)+"规则集（固定） · 胜负影响 Elo · 等待满 1 分钟后放宽分差");rules.name="MatchmakingRules"
 var match_button=mobile_action(matching,"开始自动匹配",start_matchmaking,true);match_button.name="StartMatchmaking"
 var create_width=maxf(480,app.ui_metrics.body*20+app.ui_metrics.padding*2)
 var directory_width=maxf(660,app.ui_metrics.body*16)
 var side_by_side=body.size.x>=create_width+directory_width+app.ui_metrics.gap
 var available_directory_width=body.size.x-create_width-app.ui_metrics.gap if side_by_side else body.size.x
 var seat_button_width=maxf(170,app.ui_metrics.body*7+app.ui_metrics.padding*2)
 cloud_room_columns=4 if available_directory_width>=seat_button_width*4+app.ui_metrics.gap*3 else 2
 var columns=HBoxContainer.new() if side_by_side else VBoxContainer.new()
 root.add_child(columns)
 var create=mobile_panel(columns)
 if side_by_side:
  var create_panel=create.get_parent() as PanelContainer
  create_panel.custom_minimum_size.x=create_width
  create_panel.size_flags_stretch_ratio=0.8
 mobile_text(create,"创建云端房间",true)
 cloud_title_input=mobile_edit(create,app.account_nickname+"的房间");cloud_title_input.max_length=30
 cloud_title_input.placeholder_text="房间名称"
 cloud_password_input=mobile_edit(create,"",true);cloud_password_input.max_length=32;cloud_password_input.placeholder_text="房间密码（可留空）"
 var options=HBoxContainer.new();create.add_child(options)
 format_input=OptionButton.new();options.add_child(format_input);add_formats()
 rule_input=OptionButton.new();options.add_child(rule_input)
 for rule_name in app.RuleSet.LABELS:rule_input.add_item(rule_name)
 cloud_host_slot=OptionButton.new();options.add_child(cloud_host_slot);cloud_host_slot.add_item("坐 1 号对战位");cloud_host_slot.add_item("坐 2 号对战位")
 for option in [format_input,rule_input,cloud_host_slot]:option.size_flags_horizontal=Control.SIZE_EXPAND_FILL;app.ui_metrics.button(option)
 strict_input=CheckButton.new();strict_input.text="主卡组必须 50 张";strict_input.button_pressed=true;create.add_child(strict_input)
 mobile_action(create,"创建房间",create_relay,true)
 var directory=mobile_panel(columns)
 if side_by_side:
  var directory_panel=directory.get_parent() as PanelContainer
  directory_panel.custom_minimum_size.x=directory_width
  directory_panel.size_flags_stretch_ratio=1.6
 var heading=HBoxContainer.new();directory.add_child(heading)
 mobile_text(heading,"所有云端房间",true).size_flags_horizontal=Control.SIZE_EXPAND_FILL
 mobile_action(heading,"刷新",func():cloud_directory.refresh())
 mobile_text(directory,"选择空位加入；加密房间将在加入时询问密码。")
 cloud_rooms_list=VBoxContainer.new();directory.add_child(cloud_rooms_list)
 refresh_cloud_rooms()

func refresh_cloud_rooms():
 if not is_instance_valid(cloud_rooms_list) or not cloud_selected:return
 for child in cloud_rooms_list.get_children():cloud_rooms_list.remove_child(child);child.queue_free()
 if cloud_directory.rooms.is_empty():
  mobile_text(cloud_rooms_list,"当前没有房间，可创建一个房间。")
  return
 for info in cloud_directory.rooms:
  if not info is Dictionary or not info.get("seats") is Array:continue
  var panel=mobile_panel(cloud_rooms_list)
  var status=str(info.get("status","lobby"))
  var status_text={"lobby":"等待加入","sideboarding":"赛前换备牌","choosing":"选择先后手","playing":"对局中","between":"局间准备","complete":"已结束"}.get(status,status)
  mobile_text(panel,"%s  ·  %s  ·  %s  ·  %s" % [str(info.get("name","房间")),"加密" if info.get("locked",false) else "公开",Series.format_label(int(info.get("format",3))),status_text],true)
  if status!="lobby" or info.get("watch_only",false):
   var has_observer_slot=false
   for index in range(2,mini(8,info.seats.size())):
    if str(info.seats[index]).is_empty():has_observer_slot=true
   var enter=mobile_action(panel,"进入观战（自动分配观战位）",func():choose_cloud_room_seat(info,8),true)
   enter.disabled=not has_observer_slot or str(info.get("version",""))!=session.fingerprint
   continue
  var grid=GridContainer.new();grid.columns=cloud_room_columns;panel.add_child(grid)
  grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  for index in range(mini(8,info.seats.size())):
   var occupant=str(info.seats[index]);var slot=index+1
   var caption="%d %s：%s" % [slot,"对战" if slot<=2 else "观战",occupant if not occupant.is_empty() else "空位"]
   var button=mobile_action(grid,caption,func():choose_cloud_room_seat(info,slot))
   button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   button.disabled=not occupant.is_empty() or str(info.get("version",""))!=session.fingerprint
   button.tooltip_text="版本不一致" if str(info.get("version",""))!=session.fingerprint else "选择 %d 号座位" % slot
func watch(address: String,port: int):
 session.set_display_name(name_input.text)
 var error=session.join_spectator(address,port)
 if not error.is_empty():show_error(error)
func refresh_rooms():
 if not is_instance_valid(rooms_list):return
 for child in rooms_list.get_children():rooms_list.remove_child(child);child.queue_free()
 if app.is_android:
  for id in session.discovery.rooms:
   var info=session.discovery.rooms[id]
   var line=HBoxContainer.new();rooms_list.add_child(line)
   var row=mobile_action(line,"%s · %s:%d" % [info.name,info.address,info.port],func():join(info.address,int(info.port)))
   row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   if info.version!=session.fingerprint:row.text+=" · 版本不一致";row.disabled=true
   var watch_button=mobile_action(line,"观战",func():watch(info.address,int(info.port)))
   watch_button.disabled=info.version!=session.fingerprint or not info.get("spectate",false)
  if rooms_list.get_child_count()==0:mobile_text(rooms_list,"未发现房间时，可直接填写房主地址加入。")
  return
 for id in session.discovery.rooms:
  var info=session.discovery.rooms[id]
  var line=HBoxContainer.new();rooms_list.add_child(line)
  var row=Button.new();row.custom_minimum_size=Vector2(680,68);line.add_child(row)
  row.text="%s · %s · %s · %d/2    %s:%d" % [info.name,Series.format_label(int(info.format)),app.RuleSet.label_for(str(info.get("rule_set",app.RuleSet.UNRESTRICTED))),info.players,info.address,info.port]
  if info.version!=session.fingerprint:row.text+=" · 版本不一致";row.disabled=true
  row.pressed.connect(func():join(info.address,int(info.port)))
  var watch_button=Button.new();watch_button.text="观战";watch_button.custom_minimum_size=Vector2(150,68);line.add_child(watch_button)
  watch_button.disabled=info.version!=session.fingerprint or not info.get("spectate",false)
  watch_button.pressed.connect(func():watch(info.address,int(info.port)))
 if rooms_list.get_child_count()==0:
  var label=Label.new();label.text="正在查找同一局域网内的房间…";label.custom_minimum_size=Vector2(800,58);rooms_list.add_child(label)
func cloud_seat_grid(parent: Node,columns: int) -> GridContainer:
 var grid=GridContainer.new();grid.columns=columns;parent.add_child(grid)
 grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 grid.add_theme_constant_override("h_separation",12)
 grid.add_theme_constant_override("v_separation",12)
 for index in range(8):
  var slot=index+1
  var occupant=str(session.cloud_seats[index]) if index<session.cloud_seats.size() else ""
  var tile=preload("res://net/cloud_seat_tile.gd").new()
  tile.name="CloudSeat%d" % slot
  tile.session=session;tile.slot=slot
  var ready_note="（已准备）" if slot<=2 and session.room.ready[slot-1] else ""
  tile.text="%d 号%s位\n%s%s" % [slot,"对战" if slot<=2 else "观战",occupant if not occupant.is_empty() else "空位",ready_note]
  grid.add_child(tile)
  app.ui_metrics.button(tile)
  tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  tile.custom_minimum_size=Vector2(maxf(195 if columns==4 else 150,app.ui_metrics.body*6+app.ui_metrics.padding*2),maxf(86,app.ui_metrics.hit))
  tile.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
  tile.tooltip_text="已准备的玩家不能换位" if slot<=2 and session.room.ready[slot-1] else "拖动名称可交换或移动座位" if session.can_move_cloud_seats() else ""
 return grid
func build_cloud_room_lobby():
 var room=session.room
 var root=mobile_scroll()
 var summary=mobile_panel(root)
 mobile_text(summary,"%s    %s  %d : %d  %s" % [Series.format_label(int(room.format)),room.names[0],room.scores[0],room.scores[1],room.names[1]],true)
 mobile_text(summary,"规则集：%s  ·  %s" % [app.RuleSet.label_for(str(room.get("rule_set",app.RuleSet.UNRESTRICTED))),"主卡组 50 张" if room.strict else "主卡组张数不限"])
 mobile_text(summary,"云端房间："+session.cloud_room_name if session.is_host else "你的座位：%d 号%s位" % [session.cloud_slot,"观战" if session.read_only else "对战"])
 var seat_panel_width=maxf(860,(app.ui_metrics.body*6+app.ui_metrics.padding*2)*4+app.ui_metrics.gap*3+app.ui_metrics.padding*2)
 var action_panel_width=maxf(400,app.ui_metrics.body*9)
 var side_by_side=body.size.x>=seat_panel_width+action_panel_width+app.ui_metrics.gap
 var columns=HBoxContainer.new() if side_by_side else VBoxContainer.new()
 root.add_child(columns)
 var seats=mobile_panel(columns)
 if side_by_side:
  var seat_panel=seats.get_parent() as PanelContainer
  seat_panel.custom_minimum_size.x=seat_panel_width
  seat_panel.size_flags_stretch_ratio=1.8
 mobile_text(seats,"自动匹配 · 两人对战" if session.cloud_ranked else "新的一场准备 · 房主可拖动玩家名称换位" if room.get("rematch",false) else "八个座位 · 房主可在本场开始前拖动玩家名称换位",true)
 if session.cloud_ranked:
  for index in range(2):mobile_text(seats,"%d 号对战位：%s" % [index+1,session.cloud_seats[index]])
 else:cloud_seat_grid(seats,4 if side_by_side else 2)
 mobile_text(seats,"1、2 号对战位都有人后才能开始对局")
 var actions=mobile_panel(columns)
 if side_by_side:
  var action_panel=actions.get_parent() as PanelContainer
  action_panel.custom_minimum_size.x=action_panel_width
  action_panel.size_flags_stretch_ratio=1.0
 if session.read_only:
  mobile_text(actions,"观战中 · 对局开始后自动进入战场")
  deck_choice_button(actions)
  register_deck_button(actions)
 else:
  mobile_text(actions,"对手："+("已准备" if room.ready[1-session.seat] else "未准备"),true)
  deck_choice_button(actions)
  register_deck_button(actions)
  if not room.own_deck.is_empty():mobile_text(actions,room.own_deck.name)
  mobile_text(actions,preparation_hint(room))
  var ready=mobile_action(actions,"取消准备" if room.ready[session.seat] else "准备",func():session.room_action({"name":"unready" if room.ready[session.seat] else "ready"}),true)
  ready.disabled=room.own_deck.is_empty() or not session.can_act()
 mobile_action(actions,"离开房间",func():session.leave(false);refresh(true))
func build_room():
 rooms_list=null
 var room=session.room
 if room.is_empty():return
 latency_label=app.label(body,"网络延迟 · "+session.latency_text(),Rect2(103,642,890,45),20,app.MUTED)
 latency_label.tooltip_text="双方各自测到对端的往返延迟（RTT），约每2秒更新；不需要同步电脑时钟。"
 var own=session.seat;var other=1-own
 app.box(body,Rect2(70,195,1460,604))
 app.label(body,"%s    %s  %d : %d  %s" % [Series.format_label(int(room.format)),room.names[0],room.scores[0],room.scores[1],room.names[1]],Rect2(100,210,1320,46),27,app.GOLD)
 app.label(body,"规则集："+app.RuleSet.label_for(str(room.get("rule_set",app.RuleSet.UNRESTRICTED))),Rect2(105,265,390,34),20,app.GOLD)
 app.label(body,"主卡组 50 张" if room.strict else "主卡组张数不限",Rect2(520,265,300,34),20)
 if session.cloud_mode and not session.is_host:app.label(body,"你的座位：%d 号%s位" % [session.cloud_slot,"观战" if session.read_only else "对战"],Rect2(830,265,490,34),20,app.GOLD)
 if session.read_only:
  app.label(body,session.connection_status(),Rect2(105,350,1130,65),27,app.GOLD)
  if not session.latest_snapshot.is_empty():app.button(body,"查看战场",Rect2(1070,485,355,60),func():app.return_network_battle(),true)
  app.button(body,"离开观战",Rect2(1070,714,355,48),func():session.leave(false);refresh(true))
  return
 if session.is_host:
  if session.cloud_mode:
   app.label(body,"云端房间："+session.cloud_room_name+"  ·  你的座位："+str(session.cloud_slot)+"号对战位",Rect2(105,311,1350,36),20,app.GOLD)
  else:
   var addresses=[]
   for ip in IP.get_local_addresses():
    if ":" not in ip and not ip.begins_with("127."):addresses.append(ip+":"+str(session.port))
   app.label(body,"房间地址："+" / ".join(addresses),Rect2(105,311,1130,36),18,app.MUTED)
   app.button(body,"复制地址",Rect2(1260,311,220,42),func():DisplayServer.clipboard_set(" / ".join(addresses)))
 if not session.applicant.is_empty():
  app.label(body,session.applicant.name+" 请求加入",Rect2(105,365,810,44),23)
  app.button(body,"接受",Rect2(950,365,235,48),func():session.accept_applicant(true),true)
  app.button(body,"拒绝",Rect2(1205,365,235,48),func():session.accept_applicant(false))
 elif room.status=="complete":
  app.label(body,"整场结束 · "+room.names[room.winner]+"获胜",Rect2(100,382,1180,70),31,app.GOLD)
  if room.has("end_reason"):app.label(body,room.end_reason,Rect2(105,465,1300,50),22)
  if not session.latest_snapshot.is_empty():app.button(body,"查看战场",Rect2(1070,540,355,60),func():app.return_network_battle())
  var rematch=app.button(body,"更换卡组，再来一场",Rect2(1070,620,355,60),func():session.room_action({"name":"rematch"}),true)
  rematch.disabled=not session.can_act() or session.cloud_ranked
 elif room.status=="aborted":
  app.label(body,"连接中断，对局结束 · 不计胜负",Rect2(100,382,1180,70),31,app.GOLD)
  if not session.latest_snapshot.is_empty():app.button(body,"查看战场",Rect2(1070,485,355,60),func():app.return_network_battle())
 elif room.status=="playing":
  app.label(body,"第 %d 局正在进行" % room.round,Rect2(105,370,1000,45),25)
  app.button(body,"回到战场",Rect2(1070,415,355,60),func():app.return_network_battle(),true)
 elif room.status=="choosing":
  app.label(body,"第 %d 局 · 选择先后手" % (room.round+1),Rect2(105,370,1000,45),27,app.GOLD)
  if room.round==0:
   app.label(body,"投骰结果：%s %d  ·  %s %d" % [room.names[0],room.roll["values"][0],room.names[1],room.roll["values"][1]],Rect2(105,430,900,45),23)
  else:app.label(body,room.choice_reason,Rect2(105,430,900,45),23)
  if own==room.chooser:
   app.label(body,"你取得了选择权",Rect2(105,489,700,38),22,app.GOLD)
   var first_button=app.button(body,"我方先手",Rect2(105,545,280,60),func():session.room_action({"name":"first","first":true}),true)
   var second_button=app.button(body,"我方后手",Rect2(405,545,280,60),func():session.room_action({"name":"first","first":false}))
   first_button.disabled=not session.can_act();second_button.disabled=not session.can_act()
  else:app.label(body,"等待 %s 选择先后手" % room.names[room.chooser],Rect2(105,500,900,50),22,app.GOLD)
 elif room.status in ["lobby","sideboarding","between"]:
  var lobby_row_y=365 if session.is_host else 312
  var deck_row_y=420 if session.is_host else 395
  app.label(body,"对手："+("已准备" if room.ready[other] else "未准备"),Rect2(105,lobby_row_y,620,42),21)
  if room.status=="lobby":
   if room.get("rematch",false):app.label(body,"新的一场 · 可重新选择卡组",Rect2(800,lobby_row_y,560,40),21,app.GOLD)
   deck_choice_button(body,Rect2(105,deck_row_y,665,51))
   register_deck_button(body,Rect2(800,deck_row_y,270,51))
  else:
   var sideboard=app.button(body,"调整主副卡组",Rect2(105,deck_row_y,665,51),open_sideboard)
   sideboard.disabled=room.ready[own] or not session.can_act()
   app.label(body,"赛前换备牌 · 最多换入 3 张" if room.status=="sideboarding" else "第 %d 局准备" % (room.round+1),Rect2(800,deck_row_y,650,51),25,app.GOLD)
  if not room.own_deck.is_empty():
   app.label(body,room.own_deck.name+" · 主卡组 %d / 副卡组 %d" % [room.own_deck.main.size(),room.own_deck.side.size()],Rect2(105,490 if session.is_host else 468,1030,46),22,app.GOLD)
  if not leader_reveal(room).is_empty():
   var reveal=app.label(body,leader_reveal(room),Rect2(105,520,900,30),20,app.GOLD);reveal.name="OpponentLeaderReveal"
   app.public_leader_card(body,room,other,Rect2(1260,335,140,196))
  var hint=app.label(body,preparation_hint(room),Rect2(105,555,900,65),20);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  var ready=app.button(body,"取消准备" if room.ready[own] else "准备",Rect2(1070,550,355,60),func():session.room_action({"name":"unready" if room.ready[own] else "ready"}),true)
  ready.disabled=room.own_deck.is_empty() or not session.can_act()
 if not session.connected and not session.is_host and not session.ended():
  app.button(body,"重连",Rect2(1070,650,355,52),func():
   var error=session.resume_guest()
   if not error.is_empty():show_error(error),true)
 if session.wait_choice_pending:app.button(body,"继续等待",Rect2(1070,590,355,48),func():session.continue_waiting(),true)
 app.button(body,"不再等待，离开对局" if session.disconnected_at>0 else "离开房间",Rect2(1070,714,355,48),func():
  if session.disconnected_at>0:session.stop_waiting()
  else:session.leave(false)
  refresh(true))
func open_sideboard():
 app.open_sideboard(session)

func mobile_text(parent: Node,value: String,heading: bool=false) -> Label:
 var result=Label.new();result.text=value;result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 result.add_theme_font_size_override("font_size",app.ui_metrics.title if heading else app.ui_metrics.body)
 result.add_theme_color_override("font_color",app.GOLD if heading else app.WHITE)
 parent.add_child(result);return result

func mobile_action(parent: Node,caption: String,callback: Callable,accent: bool=false) -> Button:
 var result=app.button(parent,caption,Rect2(),callback,accent)
 app.ui_metrics.button(result)
 return result

func mobile_panel(parent: Node) -> VBoxContainer:
 var panel=PanelContainer.new();parent.add_child(panel);panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 panel.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
 var content=VBoxContainer.new();panel.add_child(content)
 return content

func mobile_scroll() -> VBoxContainer:
 var scroll=ScrollContainer.new();body.add_child(scroll)
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var content=VBoxContainer.new();scroll.add_child(content)
 content.custom_minimum_size.x=body.size.x
 content.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 return content

func mobile_edit(parent: Node,value: String="",password: bool=false) -> LineEdit:
 var edit=preload("res://scripts/password_edit.gd").new() if password else LineEdit.new();edit.text=value;parent.add_child(edit)
 edit.custom_minimum_size.y=app.ui_metrics.hit
 edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 return edit

func build_mobile_home():
 var root=mobile_scroll()
 mobile_text(root,"局域网联机",true)
 var columns=HBoxContainer.new();root.add_child(columns)
 var create=mobile_panel(columns)
 mobile_text(create,"创建房间",true)
 mobile_text(create,"显示 ID")
 name_input=mobile_edit(create,session.identity.nickname);name_input.max_length=20
 mobile_text(create,"对局形式与规则集")
 format_input=OptionButton.new();create.add_child(format_input);add_formats();app.ui_metrics.button(format_input)
 rule_input=OptionButton.new();create.add_child(rule_input)
 for rule_name in app.RuleSet.LABELS:rule_input.add_item(rule_name)
 app.ui_metrics.button(rule_input)
 strict_input=CheckButton.new();strict_input.text="主卡组必须 50 张";strict_input.button_pressed=true;create.add_child(strict_input);app.ui_metrics.button(strict_input)
 mobile_text(create,"本机 UDP 对战端口")
 port_input=SpinBox.new();port_input.min_value=1024;port_input.max_value=65534;port_input.value=47861;create.add_child(port_input);port_input.custom_minimum_size.y=app.ui_metrics.hit
 interface_input=OptionButton.new();create.add_child(interface_input);interface_input.add_item("所有网卡（推荐）");interface_input.set_item_metadata(0,"*")
 for local_address in IP.get_local_addresses():
  if local_address.is_valid_ip_address() and ":" not in local_address and not local_address.begins_with("127."):
   interface_input.add_item(local_address);interface_input.set_item_metadata(interface_input.item_count-1,local_address)
 app.ui_metrics.button(interface_input)
 mobile_action(create,"创建房间",func():
  session.set_display_name(name_input.text)
  var error=session.create_room(format_input.get_selected_id(),strict_input.button_pressed,int(port_input.value),interface_input.get_selected_metadata(),app.RuleSet.IDS[rule_input.selected])
  if not error.is_empty():show_error(error),true)
 mobile_action(create,"恢复房主对局",func():
  var error=session.restore_host()
  if not error.is_empty():show_error(error))
 var connect=mobile_panel(columns)
 mobile_text(connect,"加入房间",true)
 mobile_text(connect,"房主地址（Wi-Fi IP 或 UDP 内网穿透地址）")
 address_input=mobile_edit(connect)
 address_input.placeholder_text="例如 192.168.1.5 或 example.com:47861"
 mobile_text(connect,"未在地址后填端口时，使用左侧端口。")
 var join_buttons=HBoxContainer.new();connect.add_child(join_buttons)
 mobile_action(join_buttons,"加入",func():join(address_input.text,int(port_input.value)),true).size_flags_horizontal=Control.SIZE_EXPAND_FILL
 mobile_action(join_buttons,"观战",func():watch(address_input.text,int(port_input.value))).size_flags_horizontal=Control.SIZE_EXPAND_FILL
 mobile_action(connect,"重连上次房间",func():
  session.set_display_name(name_input.text)
  var error=session.resume_guest(address_input.text)
  if not error.is_empty():show_error(error))
 mobile_text(connect,"发现的 Wi-Fi 房间",true)
 rooms_list=VBoxContainer.new();connect.add_child(rooms_list)
 mobile_text(root,"跨网络连接需要可传递 UDP 的组网或内网穿透；广播列表为空时仍可手动输入地址。")

func build_responsive_room():
 var room=session.room
 if room.is_empty():return
 var root=mobile_scroll()
 var summary=mobile_panel(root)
 mobile_text(summary,"%s  %s  %d : %d  %s" % [Series.format_label(int(room.format)),room.names[0],room.scores[0],room.scores[1],room.names[1]],true)
 if not leader_reveal(room).is_empty():
  var reveal=mobile_text(summary,leader_reveal(room));reveal.name="OpponentLeaderReveal"
  if not session.read_only:app.public_leader_card(summary,room,1-session.seat)
 mobile_text(summary,"规则集："+app.RuleSet.label_for(str(room.get("rule_set",app.RuleSet.UNRESTRICTED))))
 if session.cloud_mode and not session.is_host:mobile_text(summary,"你的座位：%d 号%s位" % [session.cloud_slot,"观战" if session.read_only else "对战"])
 latency_label=mobile_text(summary,"网络延迟 · "+session.latency_text())
 if session.is_host:
  if session.cloud_mode:
   mobile_text(summary,"云端房间："+session.cloud_room_name+"  ·  你的座位："+str(session.cloud_slot)+"号对战位")
  else:
   var addresses=[]
   for local_address in IP.get_local_addresses():
    if ":" not in local_address and not local_address.begins_with("127."):addresses.append(local_address+":"+str(session.port))
   mobile_text(summary,"房主地址："+" / ".join(addresses))
   mobile_action(summary,"复制房主地址",func():DisplayServer.clipboard_set(" / ".join(addresses)))
 if session.read_only:
  mobile_text(summary,session.connection_status())
  if not session.latest_snapshot.is_empty():mobile_action(summary,"查看战场",app.return_network_battle,true)
  mobile_action(summary,"离开观战",func():session.leave(false);refresh(true))
  return
 var actions=mobile_panel(root)
 if not session.applicant.is_empty():
  mobile_text(actions,session.applicant.name+" 请求加入",true)
  mobile_action(actions,"接受",func():session.accept_applicant(true),true)
  mobile_action(actions,"拒绝",func():session.accept_applicant(false))
 elif room.status=="complete":
  mobile_text(actions,"整场结束 · "+room.names[room.winner]+"获胜",true)
  if room.has("end_reason"):mobile_text(actions,room.end_reason)
  if not session.latest_snapshot.is_empty():mobile_action(actions,"查看战场",app.return_network_battle)
  var rematch=mobile_action(actions,"更换卡组，再来一场",func():session.room_action({"name":"rematch"}),true)
  if session.cloud_ranked:
   rematch.text="返回云端，重新匹配"
   for callback in rematch.pressed.get_connections():rematch.pressed.disconnect(callback.callable)
   rematch.pressed.connect(func():session.leave(false);refresh(true))
   rematch.disabled=not session.match_settled
   mobile_text(actions,"匹配已结算" if session.match_settled else "正在结算 Elo，请稍候")
  else:rematch.disabled=not session.can_act()
 elif room.status=="aborted":
  mobile_text(actions,"连接中断，对局结束 · 不计胜负",true)
  if not session.latest_snapshot.is_empty():mobile_action(actions,"查看战场",app.return_network_battle)
 elif room.status=="playing":
  mobile_text(actions,"第 %d 局正在进行" % room.round,true)
  mobile_action(actions,"回到战场",app.return_network_battle,true)
 elif room.status=="choosing":
  mobile_text(actions,"第 %d 局 · 选择先后手" % (room.round+1),true)
  if room.round==0:mobile_text(actions,"投骰：%s %d  ·  %s %d" % [room.names[0],room.roll.values[0],room.names[1],room.roll.values[1]])
  else:mobile_text(actions,room.choice_reason)
  if session.seat==room.chooser:
   var first=mobile_action(actions,"我方先手",func():session.room_action({"name":"first","first":true}),true)
   var second=mobile_action(actions,"我方后手",func():session.room_action({"name":"first","first":false}))
   first.disabled=not session.can_act();second.disabled=not session.can_act()
  else:mobile_text(actions,"等待 %s 选择先后手" % room.names[room.chooser])
 elif room.status in ["lobby","sideboarding","between"]:
  mobile_text(actions,"对手："+("已准备" if room.ready[1-session.seat] else "未准备"),true)
  if room.status=="lobby":
   deck_choice_button(actions)
   register_deck_button(actions)
  else:
   var sideboard=mobile_action(actions,"调整主副卡组",open_sideboard)
   sideboard.disabled=room.ready[session.seat] or not session.can_act()
  if not room.own_deck.is_empty():mobile_text(actions,room.own_deck.name+" · 主卡组 %d / 副卡组 %d" % [room.own_deck.main.size(),room.own_deck.side.size()])
  mobile_text(actions,preparation_hint(room))
  var ready=mobile_action(actions,"取消准备" if room.ready[session.seat] else "准备",func():session.room_action({"name":"unready" if room.ready[session.seat] else "ready"}),true)
  ready.disabled=room.own_deck.is_empty() or not session.can_act()
 if not session.connected and not session.is_host and not session.ended():
  mobile_action(actions,"重连",func():
   var error=session.resume_guest()
   if not error.is_empty():show_error(error),true)
 if session.wait_choice_pending:mobile_action(actions,"继续等待",func():session.continue_waiting(),true)
 mobile_action(actions,"不再等待，离开对局" if session.disconnected_at>0 else "离开房间",func():
  if session.disconnected_at>0:session.stop_waiting()
  else:session.leave(false)
  refresh(true))
