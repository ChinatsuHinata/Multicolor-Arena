extends Control
var app
var session
var body: Control
var status_label: Label
var latency_label: Label
var name_input: LineEdit
var address_input: LineEdit
var port_input: SpinBox
var format_input: OptionButton
var rule_input: OptionButton
var interface_input: OptionButton
var strict_input: CheckButton
var rooms_list: VBoxContainer
var signature=""
var deck_index=0
var last_error=""
var chat_open=false
func build(parent,net):
 app=parent;session=net;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 session.changed.connect(refresh);session.error_raised.connect(show_error)
 app.header("联机对战",func():
  if session.disconnected_at>0:session.stop_waiting()
  else:session.leave(false)
  app.menu())
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
 if is_instance_valid(latency_label):latency_label.text="网络延迟 · "+session.latency_text()
 if session.disconnected_at>0 or session.ended():status_label.text=session.connection_status()
func refresh(force: bool=false):
 status_label.text=last_error if not last_error.is_empty() else session.notice if not session.notice.is_empty() else session.discovery.error
 var next=JSON.stringify([session.room_id,session.room,session.applicant,session.connected,session.paused,session.wait_choice_pending,session.wait_choice_confirmed])
 if force or next!=signature:
  signature=next
  rooms_list=null;latency_label=null
  for child in body.get_children():body.remove_child(child);child.queue_free()
  if app.is_android:
   if session.room_id.is_empty():build_mobile_home()
   else:build_mobile_room()
  elif session.room_id.is_empty():build_home()
  else:build_room()
 refresh_rooms()
func input(text: String,rect: Rect2) -> LineEdit:
 var edit=LineEdit.new();edit.position=rect.position;edit.size=rect.size;edit.text=text;body.add_child(edit);return edit
func build_home():
 app.box(body,Rect2(70,190,500,620));app.box(body,Rect2(600,190,930,620))
 app.label(body,"显示 ID",Rect2(100,210,120,35),21)
 name_input=input(session.identity.nickname,Rect2(230,208,302,44));name_input.max_length=20
 app.label(body,"对局形式",Rect2(100,280,120,40),21)
 format_input=OptionButton.new();format_input.position=Vector2(230,279);format_input.size=Vector2(302,43);format_input.add_item("BO3 · 先赢两局");format_input.add_item("BO1 · 单局");body.add_child(format_input)
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
  var error=session.create_room(3 if format_input.selected==0 else 1,strict_input.button_pressed,int(port_input.value),interface_input.get_selected_metadata(),app.RuleSet.IDS[rule_input.selected])
  if not error.is_empty():show_error(error),true)
 app.button(body,"恢复房主对局",Rect2(100,626,432,49),func():
  var error=session.restore_host()
  if not error.is_empty():show_error(error))
 app.button(body,"重连上次房间",Rect2(100,693,432,49),func():
  session.set_display_name(name_input.text)
  var error=session.resume_guest(address_input.text)
  if not error.is_empty():show_error(error))
 app.label(body,"发现的房间",Rect2(625,208,500,43),25,app.GOLD)
 var scroll=ScrollContainer.new();scroll.position=Vector2(625,264);scroll.size=Vector2(877,350);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
 rooms_list=VBoxContainer.new();rooms_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rooms_list.add_theme_constant_override("separation",12);scroll.add_child(rooms_list)
 app.label(body,"输入地址加入",Rect2(625,638,210,40),21)
 address_input=input("",Rect2(625,690,620,49));address_input.placeholder_text="房主 IP、域名或 地址:UDP端口"
 app.button(body,"加入",Rect2(1265,690,108,49),func():join(address_input.text,int(port_input.value)),true)
 app.button(body,"观战",Rect2(1383,690,117,49),func():watch(address_input.text,int(port_input.value)))
 app.label(body,"Wi-Fi 直连或 UDP 内网穿透；首次联网请允许系统网络访问。",Rect2(625,753,855,38),17,app.MUTED)
func join(address: String,port: int):
 session.set_display_name(name_input.text)
 var error=session.join_room(address,port)
 if not error.is_empty():show_error(error)
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
  row.text="%s · BO%d · %s · %d/2    %s:%d" % [info.name,info.format,app.RuleSet.label_for(str(info.get("rule_set",app.RuleSet.UNRESTRICTED))),info.players,info.address,info.port]
  if info.version!=session.fingerprint:row.text+=" · 版本不一致";row.disabled=true
  row.pressed.connect(func():join(info.address,int(info.port)))
  var watch_button=Button.new();watch_button.text="观战";watch_button.custom_minimum_size=Vector2(150,68);line.add_child(watch_button)
  watch_button.disabled=info.version!=session.fingerprint or not info.get("spectate",false)
  watch_button.pressed.connect(func():watch(info.address,int(info.port)))
 if rooms_list.get_child_count()==0:
  var label=Label.new();label.text="正在查找同一局域网内的房间…";label.custom_minimum_size=Vector2(800,58);rooms_list.add_child(label)
func build_room():
 rooms_list=null
 var room=session.room
 if room.is_empty():return
 latency_label=app.label(body,"网络延迟 · "+session.latency_text(),Rect2(103,642,890,45),20,app.MUTED)
 if not session.read_only:
  var chat=preload("res://net/chat_panel.gd").new();body.add_child(chat);chat.build(session,Rect2(1040,299,456,410));chat.visible=chat_open;chat.z_index=20
  var chat_button=app.button(body,"聊天",Rect2(1320,254,165,38),func():chat_open=not chat_open;chat.visible=chat_open);chat_button.z_index=21
 latency_label.tooltip_text="双方各自测到对端的往返延迟（RTT），约每2秒更新；不需要同步电脑时钟。"
 var own=session.seat;var other=1-own
 app.box(body,Rect2(70,195,1460,604))
 app.label(body,"BO%d    %s  %d : %d  %s" % [room.format,room.names[0],room.scores[0],room.scores[1],room.names[1]],Rect2(100,210,1320,46),27,app.GOLD)
 app.label(body,"规则集："+app.RuleSet.label_for(str(room.get("rule_set",app.RuleSet.UNRESTRICTED))),Rect2(105,265,390,34),20,app.GOLD)
 app.label(body,"主卡组 50 张" if room.strict else "主卡组张数不限",Rect2(520,265,300,34),20)
 if session.read_only:
  app.label(body,session.connection_status(),Rect2(105,350,1130,65),27,app.GOLD)
  if not session.latest_snapshot.is_empty():app.button(body,"查看战场",Rect2(1070,485,355,60),func():app.return_network_battle(),true)
  app.button(body,"离开观战",Rect2(1070,714,355,48),func():session.leave(false);refresh(true))
  return
 if session.is_host:
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
  rematch.disabled=not session.can_act()
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
 elif room.status in ["lobby","between"]:
  app.label(body,"对手："+("已准备" if room.ready[other] else "未准备"),Rect2(105,312,620,42),21)
  if room.status=="lobby":
   if room.get("rematch",false):app.label(body,"新的一场 · 可重新选择卡组",Rect2(800,315,560,40),21,app.GOLD)
   var pick=OptionButton.new();pick.position=Vector2(105,395);pick.size=Vector2(665,51);body.add_child(pick)
   for deck in app.decks:pick.add_item(deck.name)
   deck_index=clampi(deck_index,0,maxi(0,app.decks.size()-1));pick.selected=deck_index
   pick.item_selected.connect(func(index):deck_index=index)
   app.button(body,"选择此卡组",Rect2(800,395,270,51),func():
    if app.decks.is_empty():return
    var deck=app.Store.clean_deck(app.decks[deck_index])
    var error=app.Store.validate(deck,room.get("strict",true),str(room.get("rule_set",app.RuleSet.UNRESTRICTED)))
    if not error.is_empty():show_error(error);return
    last_error="";session.room_action({"name":"deck","deck":deck}))
  else:
   var sideboard=app.button(body,"调整主副卡组",Rect2(105,395,665,51),open_sideboard)
   sideboard.disabled=room.ready[own] or not session.can_act()
   app.label(body,"第 %d 局准备" % (room.round+1),Rect2(800,395,500,51),25,app.GOLD)
  if not room.own_deck.is_empty():
   app.label(body,room.own_deck.name+" · 主卡组 %d / 副卡组 %d" % [room.own_deck.main.size(),room.own_deck.side.size()],Rect2(105,468,1030,46),22,app.GOLD)
  var choice_hint="双方准备后投骰，点数高者选择先后手" if room.status=="lobby" else "双方准备后由上一局败者选择先后手" if room.last_winner in [0,1] else "双方准备后由上一局选择者选择先后手"
  app.label(body,choice_hint,Rect2(105,552,900,45),22)
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

func mobile_edit(parent: Node,value: String="") -> LineEdit:
 var edit=LineEdit.new();edit.text=value;parent.add_child(edit)
 edit.custom_minimum_size.y=app.ui_metrics.hit
 edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 return edit

func build_mobile_home():
 var root=mobile_scroll()
 var columns=HBoxContainer.new();root.add_child(columns)
 var create=mobile_panel(columns)
 mobile_text(create,"创建房间",true)
 mobile_text(create,"显示 ID")
 name_input=mobile_edit(create,session.identity.nickname);name_input.max_length=20
 mobile_text(create,"对局形式与规则集")
 format_input=OptionButton.new();create.add_child(format_input);format_input.add_item("BO3 · 先赢两局");format_input.add_item("BO1 · 单局");app.ui_metrics.button(format_input)
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
  var error=session.create_room(3 if format_input.selected==0 else 1,strict_input.button_pressed,int(port_input.value),interface_input.get_selected_metadata(),app.RuleSet.IDS[rule_input.selected])
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

func build_mobile_room():
 var room=session.room
 if room.is_empty():return
 var root=mobile_scroll()
 var summary=mobile_panel(root)
 mobile_text(summary,"BO%d  %s  %d : %d  %s" % [room.format,room.names[0],room.scores[0],room.scores[1],room.names[1]],true)
 mobile_text(summary,"规则集："+app.RuleSet.label_for(str(room.get("rule_set",app.RuleSet.UNRESTRICTED))))
 latency_label=mobile_text(summary,"网络延迟 · "+session.latency_text())
 if session.is_host:
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
  rematch.disabled=not session.can_act()
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
 elif room.status in ["lobby","between"]:
  mobile_text(actions,"对手："+("已准备" if room.ready[1-session.seat] else "未准备"),true)
  if room.status=="lobby":
   var pick=OptionButton.new();actions.add_child(pick)
   for deck in app.decks:pick.add_item(deck.name)
   deck_index=clampi(deck_index,0,maxi(0,app.decks.size()-1));pick.selected=deck_index
   pick.item_selected.connect(func(index):deck_index=index)
   app.ui_metrics.button(pick)
   mobile_action(actions,"选择此卡组",func():
    if app.decks.is_empty():return
    var deck=app.Store.clean_deck(app.decks[deck_index])
    var error=app.Store.validate(deck,room.get("strict",true),str(room.get("rule_set",app.RuleSet.UNRESTRICTED)))
    if not error.is_empty():show_error(error);return
    last_error="";session.room_action({"name":"deck","deck":deck}))
  else:
   var sideboard=mobile_action(actions,"调整主副卡组",open_sideboard)
   sideboard.disabled=room.ready[session.seat] or not session.can_act()
  if not room.own_deck.is_empty():mobile_text(actions,room.own_deck.name+" · 主卡组 %d / 副卡组 %d" % [room.own_deck.main.size(),room.own_deck.side.size()])
  mobile_text(actions,"双方准备后开始对局" if room.status=="lobby" else "双方准备后进入下一局")
  var ready=mobile_action(actions,"取消准备" if room.ready[session.seat] else "准备",func():session.room_action({"name":"unready" if room.ready[session.seat] else "ready"}),true)
  ready.disabled=room.own_deck.is_empty() or not session.can_act()
 if not session.connected and not session.is_host and not session.ended():
  mobile_action(actions,"重连",func():
   var error=session.resume_guest()
   if not error.is_empty():show_error(error),true)
 if session.wait_choice_pending:mobile_action(actions,"继续等待",func():session.continue_waiting(),true)
 if session.connected:
  var chat=preload("res://net/chat_panel.gd").new();body.add_child(chat)
  var chat_size=Vector2(minf(620,body.size.x-20),minf(460,body.size.y-20))
  chat.build(session,Rect2((body.size-chat_size)*0.5,chat_size),true)
  chat.visible=chat_open;chat.z_index=20
  mobile_action(actions,"聊天",func():chat_open=not chat.visible;chat.visible=chat_open)
 mobile_action(actions,"不再等待，离开对局" if session.disconnected_at>0 else "离开房间",func():
  if session.disconnected_at>0:session.stop_waiting()
  else:session.leave(false)
  refresh(true))
